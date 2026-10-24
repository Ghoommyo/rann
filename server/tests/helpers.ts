// Builds the API against the test database (TEST_DATABASE_URL), wiped before each test.
import type { FastifyInstance } from "fastify";
import { afterAll, beforeAll, beforeEach } from "vitest";
import { buildApp } from "../src/app.js";
import { config } from "../src/config.js";
import { createDb, type Db } from "../src/db.js";
import { createMailer, type Mailer } from "../src/mailer.js";
import { migrate } from "../src/migrate.js";

export interface TestContext {
  app: FastifyInstance;
  db: Db;
  mailer: Mailer;
}

export function useTestApp(options: { authRateLimit?: number } = {}): TestContext {
  const ctx = {} as TestContext;
  beforeAll(async () => {
    if (!/test/.test(config.testDatabaseUrl)) throw new Error("TEST_DATABASE_URL must point at a test database (it gets wiped)");
    ctx.db = createDb(config.testDatabaseUrl);
    await migrate(ctx.db);
    ctx.mailer = createMailer("", "", () => {});
    ctx.app = await buildApp({ db: ctx.db, mailer: ctx.mailer, jwtSecret: "test-secret", authRateLimit: options.authRateLimit ?? 1000 });
  });
  beforeEach(async () => {
    await ctx.db.query("TRUNCATE users, refresh_tokens, password_resets, matches, match_reports CASCADE");
    ctx.mailer.outbox.length = 0;
  });
  afterAll(async () => {
    await ctx.app?.close();
    await ctx.db?.end();
  });
  return ctx;
}

export async function call(app: FastifyInstance, method: "GET" | "POST" | "PATCH", url: string, body?: unknown, token?: string) {
  const res = await app.inject({
    method,
    url,
    payload: body as Record<string, unknown> | undefined,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
  return { status: res.statusCode, body: res.json() as Record<string, any> };
}

export async function signup(app: FastifyInstance, username: string, email = `${username.toLowerCase()}@example.com`, password = "password123") {
  const res = await call(app, "POST", "/auth/signup", { username, email, password });
  if (res.status !== 201) throw new Error(`signup failed: ${JSON.stringify(res.body)}`);
  return res.body as { access_token: string; refresh_token: string; user: Record<string, any> };
}
