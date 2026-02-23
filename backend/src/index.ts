import { eq, and, desc } from "drizzle-orm";
import { drizzle, PostgresJsDatabase } from "drizzle-orm/postgres-js";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { createMiddleware } from "hono/factory";
import { describeRoute, openAPIRouteHandler, resolver, validator } from "hono-openapi";
import postgres from "postgres";
import { createAuth, AuthEnv } from "./auth";
import { pins } from "./db/schema";
import {
  CreatePinSchema,
  BatchCreatePinsSchema,
  PinSchema,
  PinsArraySchema,
  UserSchema,
  ErrorSchema,
  HealthSchema,
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
      const allowed = c.env.ALLOWED_ORIGINS?.split(",") ?? ["http://localhost:3000"];
      return allowed.includes(origin) ? origin : allowed[0];
    },
    allowMethods: ["GET", "POST", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization"],
    credentials: true,
    maxAge: 86400,
  })
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
  }
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
      servers: [
        { url: "http://localhost:8787", description: "Development" },
      ],
    },
  })
);

// Better Auth handler
app.on(["POST", "GET"], "/api/auth/*", async (c) => {
  const start = Date.now();
  const path = c.req.path;
  console.log(`[${new Date().toISOString()}] AUTH START: ${path}`);

  const auth = createAuth(c.env);
  const response = await auth.handler(c.req.raw);

  console.log(`[${new Date().toISOString()}] AUTH END: ${path} (${Date.now() - start}ms)`);
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
  fn: (db: PostgresJsDatabase) => Promise<T>
): Promise<T> {
  const client = postgres(connectionString, { max: 1 });
  try {
    const db = drizzle(client);
    return await fn(db);
  } finally {
    await client.end();
  }
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
  }
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
          .orderBy(desc(pins.createdAt))
      );

      console.log(`[${new Date().toISOString()}] PINS END: GET /api/pins (${Date.now() - start}ms)`);
      return c.json(data);
    } catch (error) {
      console.error("Failed to get pins:", error);
      return c.json({ error: "Failed to get pins" }, 500);
    }
  }
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

    try {
      const [data] = await withDb(c.env.DATABASE_URL, (db) =>
        db
          .insert(pins)
          .values({
            userId,
            latitude: body.latitude,
            longitude: body.longitude,
          })
          .returning()
      );

      return c.json(data, 201);
    } catch (error) {
      console.error("Failed to add pin:", error);
      return c.json({ error: "Failed to add pin" }, 500);
    }
  }
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
        db.delete(pins).where(and(eq(pins.id, pinId), eq(pins.userId, userId)))
      );

      return c.body(null, 204);
    } catch (error) {
      console.error("Failed to delete pin:", error);
      return c.json({ error: "Failed to delete pin" }, 500);
    }
  }
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

    const pinsToInsert = body.pins.map((pin) => ({
      userId,
      latitude: pin.latitude,
      longitude: pin.longitude,
    }));

    try {
      const data = await withDb(c.env.DATABASE_URL, (db) =>
        db.insert(pins).values(pinsToInsert).returning()
      );

      return c.json(data, 201);
    } catch (error) {
      console.error("Failed to batch insert pins:", error);
      return c.json({ error: "Failed to add pins" }, 500);
    }
  }
);

export default app;
