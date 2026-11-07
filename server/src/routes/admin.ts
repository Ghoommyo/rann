// The admin portal's API: log in, analytics, switching users and fighters
// on and off. Every endpoint but /login needs an admin token.
import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import { emailSchema, parse, requireAdmin, type Deps } from "../app.js";
import type { Db } from "../db.js";
import { notFound, unauthorized } from "../errors.js";
import { hashPassword, verifyPassword } from "../auth/passwords.js";
import { revokeAllSessions } from "../sessions.js";
import { getSettings, updateSettings } from "../settings.js";

const ADMIN_TOKEN_TTL = "8h";
const PAGE_SIZE = 50;

interface AdminRow {
  id: string;
  email: string;
  password_hash: string;
}

/** The admin behind the request's token (an admin removed since is refused). */
async function currentAdmin(db: Db, req: FastifyRequest): Promise<AdminRow> {
  const id = await requireAdmin(req);
  const { rows } = await db.query<AdminRow>("SELECT * FROM admins WHERE id = $1", [id]);
  if (!rows[0]) throw unauthorized();
  return rows[0];
}

/** One number per day for the last 30 days (oldest first), from a timestamp column. */
async function perDay(db: Db, table: string, column: string, distinct?: string): Promise<{ day: string; count: number }[]> {
  const counted = distinct ? `count(DISTINCT t.${distinct})` : "count(t.*)";
  const { rows } = await db.query<{ day: string; count: string }>(
    `SELECT to_char(d.day, 'YYYY-MM-DD') AS day, ${counted} AS count
     FROM generate_series(current_date - 29, current_date, interval '1 day') AS d(day)
     LEFT JOIN ${table} t ON t.${column} >= d.day AND t.${column} < d.day + interval '1 day'
     GROUP BY d.day ORDER BY d.day`,
  );
  return rows.map((r) => ({ day: r.day, count: Number(r.count) }));
}

export function adminRoutes({ db, authRateLimit }: Deps) {
  const dummyHash = hashPassword("not-a-real-password");
  const limited = { config: { rateLimit: { max: authRateLimit, timeWindow: "1 minute" } } };

  return async (app: FastifyInstance) => {
    app.post("/login", limited, async (req) => {
      const body = parse(z.object({ email: emailSchema, password: z.string().min(1, "Enter your password.") }), req.body);
      const { rows } = await db.query<AdminRow>("SELECT * FROM admins WHERE email = $1", [body.email]);
      const admin = rows[0];
      const ok = await verifyPassword(admin?.password_hash ?? (await dummyHash), body.password);
      if (!admin || !ok) throw unauthorized("Wrong email or password.");
      await db.query("UPDATE admins SET last_login_at = now() WHERE id = $1", [admin.id]);
      return { token: app.jwt.sign({ sub: admin.id, role: "admin" }, { expiresIn: ADMIN_TOKEN_TTL }), email: admin.email };
    });

    app.get("/me", async (req) => {
      const admin = await currentAdmin(db, req);
      return { email: admin.email };
    });

    app.get("/stats", async (req) => {
      await currentAdmin(db, req);
      const users = await db.query<Record<string, string>>(
        `SELECT count(*) AS total,
                count(*) FILTER (WHERE is_active) AS active,
                count(*) FILTER (WHERE NOT is_active) AS inactive,
                count(*) FILTER (WHERE disabled_by_admin) AS disabled,
                count(*) FILTER (WHERE email_verified_at IS NOT NULL) AS verified,
                count(*) FILTER (WHERE created_at > now() - interval '7 days') AS new_7d,
                count(*) FILTER (WHERE created_at > now() - interval '30 days') AS new_30d
         FROM users`,
      );
      const matches = await db.query<Record<string, string>>(
        `SELECT count(*) AS total,
                count(*) FILTER (WHERE status = 'confirmed') AS confirmed,
                count(*) FILTER (WHERE status = 'disputed') AS disputed,
                count(*) FILTER (WHERE status = 'expired') AS expired,
                count(*) FILTER (WHERE status = 'pending') AS pending,
                count(*) FILTER (WHERE created_at > now() - interval '7 days') AS last_7d
         FROM matches`,
      );
      const picks = await db.query<{ fighter: string; picks: string }>(
        `SELECT coalesce(f.name, p.id) AS fighter, count(*) AS picks FROM (
           SELECT p1_character AS id FROM matches WHERE joined_at IS NOT NULL
           UNION ALL SELECT p2_character FROM matches WHERE joined_at IS NOT NULL
         ) p LEFT JOIN fighters f ON f.id = p.id
         WHERE p.id <> '' GROUP BY 1 ORDER BY picks DESC, fighter`,
      );
      const top = await db.query<{ username: string; rating: number; games_played: number; wins: number; losses: number }>(
        `SELECT username, rating, games_played, wins, losses FROM users
         WHERE is_active AND games_played > 0 ORDER BY rating DESC LIMIT 10`,
      );
      const numbers = (row: Record<string, string>) => Object.fromEntries(Object.entries(row).map(([k, v]) => [k, Number(v)]));
      return {
        users: numbers(users.rows[0]!),
        matches: numbers(matches.rows[0]!),
        signups_per_day: await perDay(db, "users", "created_at"),
        matches_per_day: await perDay(db, "matches", "created_at"),
        // Every login and token refresh adds a refresh_tokens row.
        players_per_day: await perDay(db, "refresh_tokens", "created_at", "user_id"),
        fighter_picks: picks.rows.map((r) => ({ fighter: r.fighter, picks: Number(r.picks) })),
        top_players: top.rows.map((r) => ({ ...r, rating: Math.round(r.rating) })),
      };
    });

    app.get("/users", async (req) => {
      await currentAdmin(db, req);
      const query = parse(
        z.object({
          status: z.enum(["active", "inactive"]).default("active"),
          q: z.string().trim().max(100).default(""),
          page: z.coerce.number().int().min(1).default(1),
        }),
        req.query,
      );
      const where = `is_active = $1 AND ($2 = '' OR username ILIKE '%' || $2 || '%' OR email ILIKE '%' || $2 || '%')`;
      const params = [query.status === "active", query.q.replace(/[%_\\]/g, "\\$&")];
      const total = await db.query<{ count: string }>(`SELECT count(*) FROM users WHERE ${where}`, params);
      const { rows } = await db.query<{
        id: string; username: string; email: string; email_verified_at: Date | null; rating: number;
        games_played: number; is_active: boolean; disabled_by_admin: boolean; created_at: Date;
      }>(
        `SELECT id, username, email, email_verified_at, rating, games_played, is_active, disabled_by_admin, created_at
         FROM users WHERE ${where} ORDER BY created_at DESC LIMIT ${PAGE_SIZE} OFFSET $3`,
        [...params, (query.page - 1) * PAGE_SIZE],
      );
      return {
        total: Number(total.rows[0]!.count),
        page: query.page,
        page_size: PAGE_SIZE,
        users: rows.map((u) => ({
          id: u.id,
          username: u.username,
          email: u.email,
          email_verified: u.email_verified_at !== null,
          rating: Math.round(u.rating),
          games_played: u.games_played,
          joined: u.created_at.toISOString(),
          status: u.is_active ? "active" : u.disabled_by_admin ? "disabled" : "deactivated",
        })),
      };
    });

    const userIdSchema = z.object({ id: z.uuid("No such user.") });

    // Switch off: logged out everywhere, hidden, and can't log in again.
    app.post("/users/:id/disable", async (req) => {
      await currentAdmin(db, req);
      const { id } = parse(userIdSchema, req.params);
      const { rowCount } = await db.query(
        "UPDATE users SET is_active = false, disabled_by_admin = true, updated_at = now() WHERE id = $1",
        [id],
      );
      if (!rowCount) throw notFound("No such user.");
      await revokeAllSessions(db, id);
      return { ok: true, status: "disabled" };
    });

    app.post("/users/:id/enable", async (req) => {
      await currentAdmin(db, req);
      const { id } = parse(userIdSchema, req.params);
      const { rowCount } = await db.query(
        "UPDATE users SET is_active = true, disabled_by_admin = false, updated_at = now() WHERE id = $1",
        [id],
      );
      if (!rowCount) throw notFound("No such user.");
      return { ok: true, status: "active" };
    });

    app.get("/settings", async (req) => {
      await currentAdmin(db, req);
      return getSettings(db);
    });

    app.patch("/settings", async (req) => {
      await currentAdmin(db, req);
      const body = parse(z.object({ email_verification_required: z.boolean().optional() }).strict(), req.body);
      return updateSettings(db, body);
    });

    app.get("/fighters", async (req) => {
      await currentAdmin(db, req);
      const { rows } = await db.query("SELECT id, name, unlocked, updated_at FROM fighters ORDER BY name");
      return { fighters: rows };
    });

    app.patch("/fighters/:id", async (req) => {
      await currentAdmin(db, req);
      const { id } = req.params as { id: string };
      const body = parse(z.object({ unlocked: z.boolean() }), req.body);
      const { rows } = await db.query(
        "UPDATE fighters SET unlocked = $2, updated_at = now() WHERE id = $1 RETURNING id, name, unlocked, updated_at",
        [id, body.unlocked],
      );
      if (!rows[0]) throw notFound("No such fighter.");
      return rows[0];
    });
  };
}
