// Builds the API (without starting it), so tests can call it in-process.
import Fastify, { type FastifyInstance, type FastifyRequest } from "fastify";
import cors from "@fastify/cors";
import fastifyJwt from "@fastify/jwt";
import rateLimit from "@fastify/rate-limit";
import { z } from "zod";
import type { Db } from "./db.js";
import type { Mailer } from "./mailer.js";
import { ApiError, badRequest, unauthorized } from "./errors.js";
import { authRoutes } from "./routes/auth.js";
import { meRoutes } from "./routes/me.js";
import { userRoutes } from "./routes/users.js";
import { matchRoutes } from "./routes/matches.js";

declare module "@fastify/jwt" {
  interface FastifyJWT {
    payload: { sub: string };
    user: { sub: string };
  }
}

export interface AppOptions {
  db: Db;
  mailer: Mailer;
  jwtSecret: string;
  corsOrigins?: string[];
  /** Requests per minute per IP on login/signup/password endpoints. */
  authRateLimit?: number;
  logger?: boolean;
}

export interface Deps {
  db: Db;
  mailer: Mailer;
  authRateLimit: number;
}

export async function buildApp(options: AppOptions): Promise<FastifyInstance> {
  const app = Fastify({ logger: options.logger ?? false, trustProxy: true });

  await app.register(cors, {
    origin: options.corsOrigins ?? [],
    allowedHeaders: ["Content-Type", "Authorization"],
    methods: ["GET", "POST", "PATCH", "OPTIONS"],
  });
  await app.register(fastifyJwt, { secret: options.jwtSecret });
  await app.register(rateLimit, { global: false });

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof ApiError) {
      return reply.status(err.status).send({ error: err.code, message: err.message, field: err.field });
    }
    const status = (err as { statusCode?: number }).statusCode;
    if (status === 429) {
      return reply.status(429).send({ error: "too_many_requests", message: "Too many attempts. Wait a minute and try again." });
    }
    if (status && status < 500) {
      return reply.status(status).send({ error: "bad_request", message: (err as Error).message });
    }
    app.log.error(err);
    return reply.status(500).send({ error: "server_error", message: "Something went wrong on our side." });
  });

  const deps: Deps = { db: options.db, mailer: options.mailer, authRateLimit: options.authRateLimit ?? 10 };
  app.get("/health", async () => ({ ok: true }));
  await app.register(authRoutes(deps), { prefix: "/auth" });
  await app.register(meRoutes(deps), { prefix: "/me" });
  await app.register(userRoutes(deps));
  await app.register(matchRoutes(deps), { prefix: "/matches" });
  return app;
}

/** Validates a request body; the first problem becomes a 400 with its field. */
export function parse<T extends z.ZodType>(schema: T, data: unknown): z.infer<T> {
  const result = schema.safeParse(data ?? {});
  if (!result.success) {
    const issue = result.error.issues[0];
    const field = issue?.path[0] !== undefined ? String(issue.path[0]) : undefined;
    throw badRequest("invalid_input", issue?.message ?? "Invalid input.", field);
  }
  return result.data;
}

/** The logged-in user's id, from the "Authorization: Bearer <token>" header. */
export async function requireUserId(req: FastifyRequest): Promise<string> {
  try {
    await req.jwtVerify();
  } catch {
    throw unauthorized();
  }
  return req.user.sub;
}

// Shared field rules
export const usernameSchema = z
  .string()
  .trim()
  .regex(/^[A-Za-z0-9_]{3,20}$/, "Username must be 3–20 letters, numbers or underscores.");
export const emailSchema = z.string().trim().pipe(z.email("Enter a valid email address.")).transform((e) => e.toLowerCase());
export const passwordSchema = z.string().min(8, "Password must be at least 8 characters.").max(200, "Password is too long.");
