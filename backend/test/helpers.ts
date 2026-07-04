import { PGlite } from "@electric-sql/pglite";
import type { PgDatabase } from "drizzle-orm/pg-core";
import { drizzle } from "drizzle-orm/pglite";
import { Hono } from "hono";
import realApp from "../src/index";

// biome-ignore lint/suspicious/noExplicitAny: drizzle drivers have different HKTs
type AnyPgDb = PgDatabase<any, any, any>;

// DDL mirrors backend/src/db/schema.ts. Kept inline so tests run without
// touching real Postgres. Update both when the schema changes.
const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS "user" (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  email_verified BOOLEAN NOT NULL DEFAULT false,
  image TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "maps" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "pins" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  map_id UUID REFERENCES "maps"(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "tags" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "pin_tags" (
  pin_id UUID NOT NULL REFERENCES "pins"(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES "tags"(id) ON DELETE CASCADE,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (pin_id, tag_id)
);

CREATE TABLE IF NOT EXISTS "drawings" (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
  map_id UUID REFERENCES "maps"(id) ON DELETE CASCADE,
  points JSONB NOT NULL,
  color TEXT NOT NULL,
  stroke_width DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);
`;

export type TestHarness = {
	app: Hono;
	db: AnyPgDb;
	pg: PGlite;
	asUser(userId: string, email?: string): TestHarness;
	close(): Promise<void>;
};

export async function createTestHarness(): Promise<TestHarness> {
	const pg = new PGlite();
	const db = drizzle(pg) as unknown as AnyPgDb;
	await pg.exec(SCHEMA_SQL);

	let currentUserId: string | null = null;
	let currentEmail: string | null = null;

	const wrapper = new Hono();
	wrapper.use("*", async (c, next) => {
		// biome-ignore lint/suspicious/noExplicitAny: bypassing Hono's typed context for test injection
		const ctx = c as any;
		if (currentUserId) {
			ctx.set("userId", currentUserId);
			ctx.set("userEmail", currentEmail ?? `${currentUserId}@test`);
		}
		ctx.set("db", db);
		// Provide a stub env so realApp's CORS / Better Auth init don't crash
		if (!ctx.env) {
			ctx.env = {
				DATABASE_URL: "postgres://stub",
				BETTER_AUTH_URL: "http://localhost:0",
				BETTER_AUTH_SECRET: "stub",
				ALLOWED_ORIGINS: "http://localhost:0",
			};
		}
		await next();
	});
	// biome-ignore lint/suspicious/noExplicitAny: mounting realApp on a plain wrapper
	wrapper.route("/", realApp as any);

	const harness: TestHarness = {
		app: wrapper,
		db,
		pg,
		asUser(userId: string, email?: string) {
			currentUserId = userId;
			currentEmail = email ?? `${userId}@test`;
			return harness;
		},
		async close() {
			await pg.close();
		},
	};
	return harness;
}

export async function seedUser(
	harness: TestHarness,
	userId: string,
	email = `${userId}@test`,
): Promise<void> {
	await harness.pg.query(
		'INSERT INTO "user" (id, name, email) VALUES ($1, $2, $3)',
		[userId, userId, email],
	);
}

export async function request(
	harness: TestHarness,
	method: string,
	path: string,
	body?: unknown,
): Promise<Response> {
	const init: RequestInit = { method, headers: {} };
	if (body !== undefined) {
		init.body = JSON.stringify(body);
		(init.headers as Record<string, string>)["Content-Type"] =
			"application/json";
	}
	return await harness.app.fetch(
		new Request(`http://test.local${path}`, init),
	);
}
