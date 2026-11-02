// Sign up (with email verification), log in, sessions and "forgot password".
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { codeSchema, emailSchema, parse, passwordSchema, usernameSchema, type Deps } from "../app.js";
import { badRequest, conflict, forbidden, unauthorized } from "../errors.js";
import { hashPassword, verifyPassword } from "../auth/passwords.js";
import { sha256 } from "../auth/tokens.js";
import { sendCode, useCode } from "../emailCodes.js";
import { issueTokens, revokeAllSessions } from "../sessions.js";
import { findUserByLogin, privateProfile, type UserRow } from "../users.js";

const loginSchema = z.string().trim().min(1, "Enter your username or email.");

export function authRoutes({ db, mailer, authRateLimit }: Deps) {
  // A real hash to verify against when the user doesn't exist, so a wrong
  // username takes as long as a wrong password (no hint which one was wrong).
  const dummyHash = hashPassword("not-a-real-password");
  const limited = { config: { rateLimit: { max: authRateLimit, timeWindow: "1 minute" } } };

  return async (app: FastifyInstance) => {
    app.post("/signup", limited, async (req, reply) => {
      const body = parse(z.object({ username: usernameSchema, email: emailSchema, password: passwordSchema }), req.body);
      const taken = await db.query<{ username: string; email: string }>(
        "SELECT username, email FROM users WHERE username = $1 OR email = $2",
        [body.username, body.email],
      );
      for (const row of taken.rows) {
        if (row.username.toLowerCase() === body.username.toLowerCase()) throw conflict("username_taken", "That username is taken.", "username");
        throw conflict("email_taken", "An account with that email already exists.", "email");
      }
      let user: UserRow;
      try {
        const { rows } = await db.query<UserRow>(
          "INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING *",
          [body.username, body.email, await hashPassword(body.password)],
        );
        user = rows[0]!;
      } catch (err) {
        // Two sign-ups racing for the same name: the unique index decides.
        if ((err as { code?: string }).code === "23505") {
          const field = String((err as { constraint?: string }).constraint).includes("email") ? "email" : "username";
          throw conflict(`${field}_taken`, field === "email" ? "An account with that email already exists." : "That username is taken.", field);
        }
        throw err;
      }
      // No login yet: the account works once the emailed code is entered
      // (POST /verify-email).
      await sendCode(db, mailer, user, "verify_email");
      reply.status(201);
      return { verification_required: true, username: user.username, email: user.email };
    });

    app.post("/verify-email", limited, async (req) => {
      const body = parse(z.object({ login: loginSchema, code: codeSchema }), req.body);
      const user = await findUserByLogin(db, body.login);
      if (!user || user.email_verified_at) throw badRequest("invalid_code", "That code is wrong or has expired. Request a new one.", "code");
      await useCode(db, user.id, "verify_email", body.code);
      const { rows } = await db.query<UserRow>("UPDATE users SET email_verified_at = now(), updated_at = now() WHERE id = $1 RETURNING *", [user.id]);
      return { ...(await issueTokens(app, db, user.id)), user: await privateProfile(db, rows[0]!) };
    });

    app.post("/resend-verification", limited, async (req) => {
      const body = parse(z.object({ login: loginSchema }), req.body);
      const user = await findUserByLogin(db, body.login);
      // Same answer either way, so this can't be used to find out who has an account.
      if (user && !user.email_verified_at) await sendCode(db, mailer, user, "verify_email");
      return { ok: true };
    });

    app.post("/login", limited, async (req) => {
      const body = parse(
        z.object({ login: loginSchema, password: z.string().min(1, "Enter your password."), reactivate: z.boolean().optional() }),
        req.body,
      );
      const user = await findUserByLogin(db, body.login);
      const ok = await verifyPassword(user?.password_hash ?? (await dummyHash), body.password);
      if (!user || !ok) throw unauthorized("Wrong username/email or password.");
      if (!user.email_verified_at) throw forbidden("email_not_verified", "Confirm your email first: enter the code we emailed you.");
      if (user.disabled_by_admin) throw forbidden("account_disabled", "This account has been switched off. Contact support.");
      if (!user.is_active) {
        if (!body.reactivate) throw forbidden("account_deactivated", "This account is deactivated. Log in again to reactivate it.");
        await db.query("UPDATE users SET is_active = true, updated_at = now() WHERE id = $1", [user.id]);
        user.is_active = true;
      }
      return { ...(await issueTokens(app, db, user.id)), user: await privateProfile(db, user) };
    });

    app.post("/refresh", async (req) => {
      const body = parse(z.object({ refresh_token: z.string().min(1) }), req.body);
      const { rows } = await db.query<{ id: string; user_id: string }>(
        `UPDATE refresh_tokens t SET revoked_at = now()
         FROM users u
         WHERE t.token_hash = $1 AND t.revoked_at IS NULL AND t.expires_at > now()
           AND u.id = t.user_id AND u.is_active
         RETURNING t.id, t.user_id`,
        [sha256(body.refresh_token)],
      );
      const session = rows[0];
      if (!session) throw unauthorized();
      return issueTokens(app, db, session.user_id);
    });

    app.post("/logout", async (req) => {
      const body = parse(z.object({ refresh_token: z.string().min(1) }), req.body);
      await db.query("UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL", [sha256(body.refresh_token)]);
      return { ok: true };
    });

    app.post("/forgot-password", limited, async (req) => {
      const body = parse(z.object({ email: emailSchema }), req.body);
      const user = await findUserByLogin(db, body.email);
      // Same answer whether or not the email exists, so this can't be used
      // to find out who has an account.
      if (user && user.is_active) await sendCode(db, mailer, user, "reset_password");
      return { ok: true };
    });

    app.post("/reset-password", limited, async (req) => {
      const body = parse(
        z.object({ email: emailSchema, code: codeSchema, new_password: passwordSchema }),
        req.body,
      );
      const user = await findUserByLogin(db, body.email);
      if (!user) throw badRequest("invalid_code", "That code is wrong or has expired. Request a new one.", "code");
      await useCode(db, user.id, "reset_password", body.code);
      // The code arrived by email, so this also confirms the address.
      await db.query(
        "UPDATE users SET password_hash = $2, email_verified_at = coalesce(email_verified_at, now()), updated_at = now() WHERE id = $1",
        [user.id, await hashPassword(body.new_password)],
      );
      await revokeAllSessions(db, user.id); // log out everywhere
      return { ok: true };
    });
  };
}
