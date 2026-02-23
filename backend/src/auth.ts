import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./db/schema";

export type AuthEnv = {
  DATABASE_URL: string;
  BETTER_AUTH_SECRET: string;
  BETTER_AUTH_URL: string;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
};

export function createAuth(env: AuthEnv) {
  const client = postgres(env.DATABASE_URL);
  const db = drizzle(client, { schema });

  const isDev = env.BETTER_AUTH_URL.includes("localhost");

  return betterAuth({
    database: drizzleAdapter(db, { provider: "pg" }),
    secret: env.BETTER_AUTH_SECRET,
    baseURL: env.BETTER_AUTH_URL,
    logger: {
      level: "debug",
    },
    emailAndPassword: { enabled: true },
    socialProviders: {
      google: env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET
        ? {
            clientId: env.GOOGLE_CLIENT_ID,
            clientSecret: env.GOOGLE_CLIENT_SECRET,
          }
        : undefined,
    },
    trustedOrigins: isDev
      ? ["http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:8080"]
      : [],
    advanced: {
      useSecureCookies: !isDev,
      defaultCookieAttributes: {
        httpOnly: true,
        sameSite: "lax",
        secure: !isDev,
        path: "/",
      },
    },
    session: {
      expiresIn: 60 * 60 * 24 * 7,
      updateAge: 60 * 60 * 24,
      cookieCache: {
        enabled: true,
        maxAge: 5 * 60,
      },
    },
  });
}

export type Auth = ReturnType<typeof createAuth>;
