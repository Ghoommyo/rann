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

// The mailer of the app under test, so signup() can read the emailed code.
let currentMailer: Mailer;

export function useTestApp(options: { authRateLimit?: number } = {}): TestContext {
  const ctx = {} as TestContext;
  beforeAll(async () => {
    if (!/test/.test(config.testDatabaseUrl)) throw new Error("TEST_DATABASE_URL must point at a test database (it gets wiped)");
    ctx.db = createDb(config.testDatabaseUrl);
    await migrate(ctx.db);
    ctx.mailer = createMailer("", "", () => {});
    currentMailer = ctx.mailer;
    ctx.app = await buildApp({ db: ctx.db, mailer: ctx.mailer, jwtSecret: "test-secret", authRateLimit: options.authRateLimit ?? 1000 });
  });
  beforeEach(async () => {
    await ctx.db.query("TRUNCATE users, refresh_tokens, email_codes, matches, match_reports CASCADE");
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

/** The code in the newest email to `to`. */
export function lastCode(to: string): string {
  const mail = currentMailer.outbox.filter((m) => m.to === to.toLowerCase()).at(-1);
  if (!mail) throw new Error(`no email to ${to}`);
  return /code is (\d{6})/.exec(mail.text)![1]!;
}

/** Signs up and confirms the email: a ready-to-use account. */
export async function signup(app: FastifyInstance, username: string, email = `${username.toLowerCase()}@example.com`, password = "password123") {
  const res = await call(app, "POST", "/auth/signup", { username, email, password });
  if (res.status !== 201) throw new Error(`signup failed: ${JSON.stringify(res.body)}`);
  const verified = await call(app, "POST", "/auth/verify-email", { login: username, code: lastCode(email) });
  if (verified.status !== 200) throw new Error(`verify failed: ${JSON.stringify(verified.body)}`);
  return verified.body as { access_token: string; refresh_token: string; user: Record<string, any> };
}
