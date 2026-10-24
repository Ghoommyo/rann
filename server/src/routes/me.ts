// The logged-in player's profile and account settings.
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { emailSchema, parse, passwordSchema, requireUserId, usernameSchema, type Deps } from "../app.js";
import { badRequest, conflict, unauthorized } from "../errors.js";
import { hashPassword, verifyPassword } from "../auth/passwords.js";
import { issueTokens, revokeAllSessions } from "../sessions.js";
import { findUserById, privateProfile, type UserRow } from "../users.js";
import type { Db } from "../db.js";

async function activeUser(db: Db, userId: string): Promise<UserRow> {
  const user = await findUserById(db, userId);
  if (!user || !user.is_active) throw unauthorized();
  return user;
}

async function checkPassword(user: UserRow, password: string, field = "password"): Promise<void> {
  if (!(await verifyPassword(user.password_hash, password))) throw badRequest("wrong_password", "That password is wrong.", field);
}

/** Runs an UPDATE that may hit a unique index, turning a clash into a 409. */
async function updateUnique(db: Db, sql: string, params: unknown[], field: "username" | "email"): Promise<void> {
  try {
    await db.query(sql, params);
  } catch (err) {
    if ((err as { code?: string }).code === "23505") {
      throw conflict(`${field}_taken`, field === "email" ? "An account with that email already exists." : "That username is taken.", field);
    }
    throw err;
  }
}

export function meRoutes({ db }: Deps) {
  return async (app: FastifyInstance) => {
    app.get("/", async (req) => privateProfile(db, await activeUser(db, await requireUserId(req))));

    app.patch("/", async (req) => {
      const user = await activeUser(db, await requireUserId(req));
      const body = parse(z.object({ bio: z.string().trim().max(300, "Bio can be at most 300 characters.") }), req.body);
      await db.query("UPDATE users SET bio = $2, updated_at = now() WHERE id = $1", [user.id, body.bio]);
      return privateProfile(db, (await findUserById(db, user.id))!);
    });

    app.patch("/username", async (req) => {
      const user = await activeUser(db, await requireUserId(req));
      const body = parse(z.object({ username: usernameSchema }), req.body);
      await updateUnique(db, "UPDATE users SET username = $2, updated_at = now() WHERE id = $1", [user.id, body.username], "username");
      return privateProfile(db, (await findUserById(db, user.id))!);
    });

    app.patch("/email", async (req) => {
      const user = await activeUser(db, await requireUserId(req));
      const body = parse(z.object({ email: emailSchema, password: z.string() }), req.body);
      await checkPassword(user, body.password);
      await updateUnique(db, "UPDATE users SET email = $2, updated_at = now() WHERE id = $1", [user.id, body.email], "email");
      return privateProfile(db, (await findUserById(db, user.id))!);
    });

    app.patch("/password", async (req) => {
      const user = await activeUser(db, await requireUserId(req));
      const body = parse(z.object({ current_password: z.string(), new_password: passwordSchema }), req.body);
      await checkPassword(user, body.current_password, "current_password");
      await db.query("UPDATE users SET password_hash = $2, updated_at = now() WHERE id = $1", [user.id, await hashPassword(body.new_password)]);
      // Log out every other device; this one gets a fresh session.
      await revokeAllSessions(db, user.id);
      return issueTokens(app, db, user.id);
    });

    app.post("/deactivate", async (req) => {
      const user = await activeUser(db, await requireUserId(req));
      const body = parse(z.object({ password: z.string() }), req.body);
      await checkPassword(user, body.password);
      await db.query("UPDATE users SET is_active = false, updated_at = now() WHERE id = $1", [user.id]);
      await revokeAllSessions(db, user.id);
      return { ok: true };
    });
  };
}
