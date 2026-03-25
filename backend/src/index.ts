import { and, desc, eq } from "drizzle-orm";
import { drizzle, type PostgresJsDatabase } from "drizzle-orm/postgres-js";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { createMiddleware } from "hono/factory";
import {
	describeRoute,
	openAPIRouteHandler,
	resolver,
	validator,
} from "hono-openapi";
import postgres from "postgres";
import { type AuthEnv, createAuth } from "./auth";
import { drawings, maps, pins } from "./db/schema";
import {
	BatchCreateDrawingsSchema,
	CreateDrawingSchema,
	DrawingSchema,
	DrawingsArraySchema,
} from "./schemas/drawing";
import {
	CreateMapSchema,
	MapSchema,
	MapsArraySchema,
	UpdateMapSchema,
} from "./schemas/map";
import {
	BatchCreatePinsSchema,
	CreatePinSchema,
	ErrorSchema,
	HealthSchema,
	PinSchema,
	PinsArraySchema,
	UserSchema,
} from "./schemas/pin";

type Bindings = AuthEnv & {
	ALLOWED_ORIGINS?: string;
};

type Variables = {
	userId: string;
	userEmail: string;
};

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

app.use(
	"/*",
	cors({
		origin: (origin, c) => {
			const allowed = c.env.ALLOWED_ORIGINS?.split(",") ?? [
				"http://localhost:3000",
			];
			return allowed.includes(origin) ? origin : allowed[0];
		},
		allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
		allowHeaders: ["Content-Type", "Authorization"],
		credentials: true,
		maxAge: 86400,
	}),
);

app.get(
	"/health",
	describeRoute({
		tags: ["system"],
		summary: "Health check",
		responses: {
			200: {
				description: "Server is healthy",
				content: { "application/json": { schema: resolver(HealthSchema) } },
			},
		},
	}),
	(c) => {
		return c.json({ status: "ok", timestamp: new Date().toISOString() });
	},
);

app.get(
	"/doc",
	openAPIRouteHandler(app, {
		documentation: {
			info: {
				title: "Memomap API",
				version: "1.0.0",
				description: "Backend API for Memomap application",
			},
			servers: [{ url: "http://localhost:8787", description: "Development" }],
		},
	}),
);

// Better Auth handler
app.on(["POST", "GET"], "/api/auth/*", async (c) => {
	const start = Date.now();
	const path = c.req.path;
	console.log(`[${new Date().toISOString()}] AUTH START: ${path}`);

	const auth = createAuth(c.env);
	const response = await auth.handler(c.req.raw);

	console.log(
		`[${new Date().toISOString()}] AUTH END: ${path} (${Date.now() - start}ms)`,
	);
	return response;
});

const authMiddleware = createMiddleware<{
	Bindings: Bindings;
	Variables: Variables;
}>(async (c, next) => {
	try {
		const auth = createAuth(c.env);
		const session = await auth.api.getSession({ headers: c.req.raw.headers });

		if (!session?.user) {
			return c.json({ error: "Unauthorized" }, 401);
		}

		c.set("userId", session.user.id);
		c.set("userEmail", session.user.email ?? "");
		await next();
	} catch (error) {
		console.error("Auth failed:", error);
		return c.json({ error: "Unauthorized" }, 401);
	}
});

async function withDb<T>(
	connectionString: string,
	fn: (db: PostgresJsDatabase) => Promise<T>,
): Promise<T> {
	const client = postgres(connectionString, { max: 1 });
	try {
		const db = drizzle(client);
		return await fn(db);
	} finally {
		await client.end();
	}
}

async function validateMapOwnership(
	connectionString: string,
	mapId: string | null | undefined,
	userId: string,
): Promise<boolean> {
	if (!mapId) return true;
	const result = await withDb(connectionString, (db) =>
		db
			.select({ id: maps.id })
			.from(maps)
			.where(and(eq(maps.id, mapId), eq(maps.userId, userId)))
			.limit(1),
	);
	return result.length > 0;
}

app.get(
	"/api/me",
	describeRoute({
		tags: ["user"],
		summary: "Get current user info",
		responses: {
			200: {
				description: "Current user information",
				content: { "application/json": { schema: resolver(UserSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	(c) => {
		return c.json({
			userId: c.get("userId"),
			email: c.get("userEmail"),
		});
	},
);

app.get(
	"/api/pins",
	describeRoute({
		tags: ["pins"],
		summary: "Get all pins for current user",
		responses: {
			200: {
				description: "List of pins",
				content: { "application/json": { schema: resolver(PinsArraySchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	async (c) => {
		const start = Date.now();
		console.log(`[${new Date().toISOString()}] PINS START: GET /api/pins`);

		const userId = c.get("userId");

		try {
			const data = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.select()
					.from(pins)
					.where(eq(pins.userId, userId))
					.orderBy(desc(pins.createdAt)),
			);

			console.log(
				`[${new Date().toISOString()}] PINS END: GET /api/pins (${Date.now() - start}ms)`,
			);
			return c.json(data);
		} catch (error) {
			console.error("Failed to get pins:", error);
			return c.json({ error: "Failed to get pins" }, 500);
		}
	},
);

app.post(
	"/api/pins",
	describeRoute({
		tags: ["pins"],
		summary: "Create a new pin",
		responses: {
			201: {
				description: "Pin created",
				content: { "application/json": { schema: resolver(PinSchema) } },
			},
			400: {
				description: "Invalid request",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	validator("json", CreatePinSchema),
	async (c) => {
		const userId = c.get("userId");
		const body = c.req.valid("json");

		if (
			!(await validateMapOwnership(c.env.DATABASE_URL, body.mapId, userId))
		) {
			return c.json({ error: "Map not found" }, 404);
		}

		try {
			const [data] = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.insert(pins)
					.values({
						userId,
						mapId: body.mapId ?? null,
						latitude: body.latitude,
						longitude: body.longitude,
					})
					.returning(),
			);

			return c.json(data, 201);
		} catch (error) {
			console.error("Failed to add pin:", error);
			return c.json({ error: "Failed to add pin" }, 500);
		}
	},
);

app.delete(
	"/api/pins/:id",
	describeRoute({
		tags: ["pins"],
		summary: "Delete a pin",
		responses: {
			204: {
				description: "Pin deleted",
			},
			400: {
				description: "Invalid pin ID",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	async (c) => {
		const userId = c.get("userId");
		const pinId = c.req.param("id");

		if (!pinId || !/^[0-9a-f-]{36}$/i.test(pinId)) {
			return c.json({ error: "Invalid pin ID" }, 400);
		}

		try {
			await withDb(c.env.DATABASE_URL, (db) =>
				db.delete(pins).where(and(eq(pins.id, pinId), eq(pins.userId, userId))),
			);

			return c.body(null, 204);
		} catch (error) {
			console.error("Failed to delete pin:", error);
			return c.json({ error: "Failed to delete pin" }, 500);
		}
	},
);

app.post(
	"/api/pins/batch",
	describeRoute({
		tags: ["pins"],
		summary: "Create multiple pins at once",
		responses: {
			201: {
				description: "Pins created",
				content: { "application/json": { schema: resolver(PinsArraySchema) } },
			},
			400: {
				description: "Invalid request",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	validator("json", BatchCreatePinsSchema),
	async (c) => {
		const userId = c.get("userId");
		const body = c.req.valid("json");

		const mapIds = [...new Set(body.pins.map((p) => p.mapId).filter(Boolean))];
		for (const mapId of mapIds) {
			if (!(await validateMapOwnership(c.env.DATABASE_URL, mapId, userId))) {
				return c.json({ error: "Map not found" }, 404);
			}
		}

		const pinsToInsert = body.pins.map((pin) => ({
			userId,
			mapId: pin.mapId ?? null,
			latitude: pin.latitude,
			longitude: pin.longitude,
		}));

		try {
			const data = await withDb(c.env.DATABASE_URL, (db) =>
				db.insert(pins).values(pinsToInsert).returning(),
			);

			return c.json(data, 201);
		} catch (error) {
			console.error("Failed to batch insert pins:", error);
			return c.json({ error: "Failed to add pins" }, 500);
		}
	},
);

// Drawings API

app.get(
	"/api/drawings",
	describeRoute({
		tags: ["drawings"],
		summary: "Get all drawings for current user",
		responses: {
			200: {
				description: "List of drawings",
				content: {
					"application/json": { schema: resolver(DrawingsArraySchema) },
				},
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	async (c) => {
		const userId = c.get("userId");

		try {
			const data = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.select()
					.from(drawings)
					.where(eq(drawings.userId, userId))
					.orderBy(desc(drawings.createdAt)),
			);

			return c.json(data);
		} catch (error) {
			console.error("Failed to get drawings:", error);
			return c.json({ error: "Failed to get drawings" }, 500);
		}
	},
);

app.post(
	"/api/drawings",
	describeRoute({
		tags: ["drawings"],
		summary: "Create a new drawing",
		responses: {
			201: {
				description: "Drawing created",
				content: { "application/json": { schema: resolver(DrawingSchema) } },
			},
			400: {
				description: "Invalid request",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	validator("json", CreateDrawingSchema),
	async (c) => {
		const userId = c.get("userId");
		const body = c.req.valid("json");

		if (
			!(await validateMapOwnership(c.env.DATABASE_URL, body.mapId, userId))
		) {
			return c.json({ error: "Map not found" }, 404);
		}

		try {
			const [data] = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.insert(drawings)
					.values({
						userId,
						mapId: body.mapId ?? null,
						points: body.points,
						color: body.color,
						strokeWidth: body.strokeWidth,
					})
					.returning(),
			);

			return c.json(data, 201);
		} catch (error) {
			console.error("Failed to add drawing:", error);
			return c.json({ error: "Failed to add drawing" }, 500);
		}
	},
);

app.delete(
	"/api/drawings/:id",
	describeRoute({
		tags: ["drawings"],
		summary: "Delete a drawing",
		responses: {
			204: {
				description: "Drawing deleted",
			},
			400: {
				description: "Invalid drawing ID",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	async (c) => {
		const userId = c.get("userId");
		const drawingId = c.req.param("id");

		if (!drawingId || !/^[0-9a-f-]{36}$/i.test(drawingId)) {
			return c.json({ error: "Invalid drawing ID" }, 400);
		}

		try {
			await withDb(c.env.DATABASE_URL, (db) =>
				db
					.delete(drawings)
					.where(and(eq(drawings.id, drawingId), eq(drawings.userId, userId))),
			);

			return c.body(null, 204);
		} catch (error) {
			console.error("Failed to delete drawing:", error);
			return c.json({ error: "Failed to delete drawing" }, 500);
		}
	},
);

app.post(
	"/api/drawings/batch",
	describeRoute({
		tags: ["drawings"],
		summary: "Create multiple drawings at once",
		responses: {
			201: {
				description: "Drawings created",
				content: {
					"application/json": { schema: resolver(DrawingsArraySchema) },
				},
			},
			400: {
				description: "Invalid request",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	validator("json", BatchCreateDrawingsSchema),
	async (c) => {
		const userId = c.get("userId");
		const body = c.req.valid("json");

		const mapIds = [
			...new Set(body.drawings.map((d) => d.mapId).filter(Boolean)),
		];
		for (const mapId of mapIds) {
			if (!(await validateMapOwnership(c.env.DATABASE_URL, mapId, userId))) {
				return c.json({ error: "Map not found" }, 404);
			}
		}

		const drawingsToInsert = body.drawings.map((drawing) => ({
			userId,
			mapId: drawing.mapId ?? null,
			points: drawing.points,
			color: drawing.color,
			strokeWidth: drawing.strokeWidth,
		}));

		try {
			const data = await withDb(c.env.DATABASE_URL, (db) =>
				db.insert(drawings).values(drawingsToInsert).returning(),
			);

			return c.json(data, 201);
		} catch (error) {
			console.error("Failed to batch insert drawings:", error);
			return c.json({ error: "Failed to add drawings" }, 500);
		}
	},
);

// Maps API

app.get(
	"/api/maps",
	describeRoute({
		tags: ["maps"],
		summary: "Get all maps for current user",
		responses: {
			200: {
				description: "List of maps",
				content: { "application/json": { schema: resolver(MapsArraySchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	async (c) => {
		const userId = c.get("userId");

		try {
			const data = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.select()
					.from(maps)
					.where(eq(maps.userId, userId))
					.orderBy(desc(maps.createdAt)),
			);

			return c.json(data);
		} catch (error) {
			console.error("Failed to get maps:", error);
			return c.json({ error: "Failed to get maps" }, 500);
		}
	},
);

app.post(
	"/api/maps",
	describeRoute({
		tags: ["maps"],
		summary: "Create a new map",
		responses: {
			201: {
				description: "Map created",
				content: { "application/json": { schema: resolver(MapSchema) } },
			},
			400: {
				description: "Invalid request",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	validator("json", CreateMapSchema),
	async (c) => {
		const userId = c.get("userId");
		const body = c.req.valid("json");

		try {
			const [data] = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.insert(maps)
					.values({
						userId,
						name: body.name,
						description: body.description ?? null,
					})
					.returning(),
			);

			return c.json(data, 201);
		} catch (error) {
			console.error("Failed to create map:", error);
			return c.json({ error: "Failed to create map" }, 500);
		}
	},
);

app.put(
	"/api/maps/:id",
	describeRoute({
		tags: ["maps"],
		summary: "Update a map",
		responses: {
			200: {
				description: "Map updated",
				content: { "application/json": { schema: resolver(MapSchema) } },
			},
			400: {
				description: "Invalid request",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			404: {
				description: "Map not found",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	validator("json", UpdateMapSchema),
	async (c) => {
		const userId = c.get("userId");
		const mapId = c.req.param("id");
		const body = c.req.valid("json");

		if (!mapId || !/^[0-9a-f-]{36}$/i.test(mapId)) {
			return c.json({ error: "Invalid map ID" }, 400);
		}

		try {
			const updateData: { name?: string; description?: string | null } = {};
			if (body.name !== undefined) updateData.name = body.name;
			if (body.description !== undefined)
				updateData.description = body.description;

			if (Object.keys(updateData).length === 0) {
				return c.json({ error: "No fields to update" }, 400);
			}

			const [data] = await withDb(c.env.DATABASE_URL, (db) =>
				db
					.update(maps)
					.set(updateData)
					.where(and(eq(maps.id, mapId), eq(maps.userId, userId)))
					.returning(),
			);

			if (!data) {
				return c.json({ error: "Map not found" }, 404);
			}

			return c.json(data);
		} catch (error) {
			console.error("Failed to update map:", error);
			return c.json({ error: "Failed to update map" }, 500);
		}
	},
);

app.delete(
	"/api/maps/:id",
	describeRoute({
		tags: ["maps"],
		summary: "Delete a map (and all associated pins/drawings)",
		responses: {
			204: {
				description: "Map deleted",
			},
			400: {
				description: "Invalid map ID",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			401: {
				description: "Unauthorized",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
			500: {
				description: "Internal server error",
				content: { "application/json": { schema: resolver(ErrorSchema) } },
			},
		},
	}),
	authMiddleware,
	async (c) => {
		const userId = c.get("userId");
		const mapId = c.req.param("id");

		if (!mapId || !/^[0-9a-f-]{36}$/i.test(mapId)) {
			return c.json({ error: "Invalid map ID" }, 400);
		}

		try {
			await withDb(c.env.DATABASE_URL, (db) =>
				db.delete(maps).where(and(eq(maps.id, mapId), eq(maps.userId, userId))),
			);

			return c.body(null, 204);
		} catch (error) {
			console.error("Failed to delete map:", error);
			return c.json({ error: "Failed to delete map" }, 500);
		}
	},
);

export default app;
