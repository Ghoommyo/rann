// Reading users and turning database rows into API responses.
import type { Queryable } from "./db.js";

export interface UserRow {
  id: string;
  username: string;
  email: string;
  password_hash: string;
  bio: string;
  is_active: boolean;
  rating: number;
  rating_deviation: number;
  volatility: number;
  games_played: number;
  wins: number;
  losses: number;
  draws: number;
  created_at: Date;
}

export async function findUserById(db: Queryable, id: string): Promise<UserRow | null> {
  const { rows } = await db.query<UserRow>("SELECT * FROM users WHERE id = $1", [id]);
  return rows[0] ?? null;
}

/** By username, or by email when `login` contains "@". Case-insensitive. */
export async function findUserByLogin(db: Queryable, login: string): Promise<UserRow | null> {
  const column = login.includes("@") ? "email" : "username";
  const { rows } = await db.query<UserRow>(`SELECT * FROM users WHERE ${column} = $1`, [login.trim()]);
  return rows[0] ?? null;
}

/** Leaderboard position among active, rated players (null until the first ranked game). */
export async function rankOf(db: Queryable, user: UserRow): Promise<number | null> {
  if (user.games_played === 0 || !user.is_active) return null;
  const { rows } = await db.query<{ above: string }>(
    "SELECT count(*) AS above FROM users WHERE is_active AND games_played > 0 AND rating > $1",
    [user.rating],
  );
  return Number(rows[0]!.above) + 1;
}

/** What anyone can see about a player. */
export async function publicProfile(db: Queryable, user: UserRow) {
  return {
    username: user.username,
    bio: user.bio,
    rating: Math.round(user.rating),
    rating_deviation: Math.round(user.rating_deviation),
    rank: await rankOf(db, user),
    games_played: user.games_played,
    wins: user.wins,
    losses: user.losses,
    draws: user.draws,
    member_since: user.created_at.toISOString(),
  };
}

/** What the logged-in player sees about themselves. */
export async function privateProfile(db: Queryable, user: UserRow) {
  return { ...(await publicProfile(db, user)), email: user.email, is_active: user.is_active };
}
