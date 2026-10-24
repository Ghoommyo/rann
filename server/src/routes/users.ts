// Public profiles and the leaderboard. Deactivated accounts are hidden.
import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { parse, type Deps } from "../app.js";
import { notFound } from "../errors.js";
import { findUserByLogin, type UserRow } from "../users.js";
import { publicProfile } from "../users.js";

export function userRoutes({ db }: Deps) {
  return async (app: FastifyInstance) => {
    app.get("/users/:username", async (req) => {
      const { username } = req.params as { username: string };
      const user = await findUserByLogin(db, username.replace("@", ""));
      if (!user || !user.is_active) throw notFound("No player with that username.");
      return publicProfile(db, user);
    });

    app.get("/leaderboard", async (req) => {
      const { limit } = parse(z.object({ limit: z.coerce.number().int().min(1).max(100).default(50) }), req.query);
      const { rows } = await db.query<UserRow>(
        "SELECT * FROM users WHERE is_active AND games_played > 0 ORDER BY rating DESC, games_played DESC LIMIT $1",
        [limit],
      );
      return {
        players: rows.map((u, i) => ({
          rank: i + 1,
          username: u.username,
          rating: Math.round(u.rating),
          games_played: u.games_played,
          wins: u.wins,
          losses: u.losses,
        })),
      };
    });
  };
}
