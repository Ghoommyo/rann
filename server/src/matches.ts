// Ranked matches. Online fights are peer-to-peer, so the server never sees the
// fight itself: both players report who won.
//  - Both reports agree     → confirmed, ratings change.
//  - Reports disagree       → disputed, nothing changes.
//  - Only one report after REPORT_WINDOW (the other player quit or lost
//    connection) → that report counts, so leaving a lost match still loses.
//  - No report after EXPIRE_AFTER → expired.
import type pg from "pg";
import { transaction, type Db } from "./db.js";
import { badRequest, conflict, forbidden, notFound } from "./errors.js";
import { updateRating } from "./rating/glicko2.js";
import type { UserRow } from "./users.js";

export const REPORT_WINDOW_MS = 3 * 60 * 1000;
export const EXPIRE_AFTER_MS = 60 * 60 * 1000;

export type Result = "p1" | "p2" | "draw";

export interface MatchRow {
  id: string;
  player1_id: string;
  player2_id: string;
  status: "pending" | "confirmed" | "disputed" | "expired";
  result: Result | null;
  p1_rating_change: number | null;
  p2_rating_change: number | null;
}

export async function createMatch(db: Db, hostId: string, opponentUsername: string, p1Character: string, p2Character: string): Promise<string> {
  const { rows } = await db.query<UserRow>("SELECT * FROM users WHERE username = $1", [opponentUsername]);
  const opponent = rows[0];
  if (!opponent || !opponent.is_active) throw notFound("No player with that username.");
  if (opponent.id === hostId) throw badRequest("self_match", "You can't play a ranked match against yourself.");
  const { rows: created } = await db.query<{ id: string }>(
    "INSERT INTO matches (player1_id, player2_id, p1_character, p2_character) VALUES ($1, $2, $3, $4) RETURNING id",
    [hostId, opponent.id, p1Character, p2Character],
  );
  return created[0]!.id;
}

export async function submitReport(db: Db, matchId: string, userId: string, result: Result): Promise<MatchRow> {
  return transaction(db, async (client) => {
    const match = await lockMatch(client, matchId);
    if (match.player1_id !== userId && match.player2_id !== userId) throw forbidden("not_a_player", "You didn't play in this match.");
    if (match.status !== "pending") return match;
    const inserted = await client.query(
      "INSERT INTO match_reports (match_id, reporter_id, result) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
      [matchId, userId, result],
    );
    if (inserted.rowCount === 0) throw conflict("already_reported", "You already reported this match.");
    const { rows: reports } = await client.query<{ result: Result }>("SELECT result FROM match_reports WHERE match_id = $1", [matchId]);
    if (reports.length < 2) return match;
    if (reports[0]!.result === reports[1]!.result) return applyResult(client, match, reports[0]!.result);
    const { rows } = await client.query<MatchRow>(
      "UPDATE matches SET status = 'disputed', resolved_at = now() WHERE id = $1 RETURNING *",
      [matchId],
    );
    return rows[0]!;
  });
}

/** Settles matches whose report window has passed. `now` is a parameter for tests. */
export async function resolveStaleMatches(db: Db, now = new Date()): Promise<{ confirmed: number; expired: number }> {
  const reportCutoff = new Date(now.getTime() - REPORT_WINDOW_MS);
  const expireCutoff = new Date(now.getTime() - EXPIRE_AFTER_MS);
  const { rows: oneReport } = await db.query<{ id: string }>(
    `SELECT m.id FROM matches m JOIN match_reports r ON r.match_id = m.id
     WHERE m.status = 'pending'
     GROUP BY m.id HAVING count(*) = 1 AND max(r.created_at) < $1`,
    [reportCutoff],
  );
  let confirmed = 0;
  for (const { id } of oneReport) {
    await transaction(db, async (client) => {
      const match = await lockMatch(client, id);
      if (match.status !== "pending") return;
      const { rows } = await client.query<{ result: Result }>("SELECT result FROM match_reports WHERE match_id = $1", [id]);
      if (rows.length !== 1) return;
      await applyResult(client, match, rows[0]!.result);
      confirmed++;
    });
  }
  const expired = await db.query(
    `UPDATE matches m SET status = 'expired', resolved_at = now()
     WHERE m.status = 'pending' AND m.created_at < $1
       AND NOT EXISTS (SELECT 1 FROM match_reports r WHERE r.match_id = m.id)`,
    [expireCutoff],
  );
  return { confirmed, expired: expired.rowCount ?? 0 };
}

async function lockMatch(client: pg.PoolClient, matchId: string): Promise<MatchRow> {
  const { rows } = await client.query<MatchRow>("SELECT * FROM matches WHERE id = $1 FOR UPDATE", [matchId]);
  if (!rows[0]) throw notFound("No such match.");
  return rows[0];
}

/** Updates both players' ratings and stats, and confirms the match. */
async function applyResult(client: pg.PoolClient, match: MatchRow, result: Result): Promise<MatchRow> {
  // Lock both players in a fixed order so two matches can't deadlock.
  const { rows: players } = await client.query<UserRow>(
    "SELECT * FROM users WHERE id = ANY($1) ORDER BY id FOR UPDATE",
    [[match.player1_id, match.player2_id]],
  );
  const p1 = players.find((u) => u.id === match.player1_id)!;
  const p2 = players.find((u) => u.id === match.player2_id)!;
  const p1Score = result === "p1" ? 1 : result === "draw" ? 0.5 : 0;
  const asRating = (u: UserRow) => ({ rating: u.rating, deviation: u.rating_deviation, volatility: u.volatility });
  const p1New = updateRating(asRating(p1), [{ opponent: asRating(p2), score: p1Score }]);
  const p2New = updateRating(asRating(p2), [{ opponent: asRating(p1), score: 1 - p1Score }]);

  const save = (u: UserRow, r: typeof p1New, score: number) =>
    client.query(
      `UPDATE users SET rating = $2, rating_deviation = $3, volatility = $4,
         games_played = games_played + 1,
         wins = wins + $5, losses = losses + $6, draws = draws + $7, updated_at = now()
       WHERE id = $1`,
      [u.id, r.rating, r.deviation, r.volatility, score === 1 ? 1 : 0, score === 0 ? 1 : 0, score === 0.5 ? 1 : 0],
    );
  await save(p1, p1New, p1Score);
  await save(p2, p2New, 1 - p1Score);

  const { rows } = await client.query<MatchRow>(
    `UPDATE matches SET status = 'confirmed', result = $2, p1_rating_change = $3, p2_rating_change = $4, resolved_at = now()
     WHERE id = $1 RETURNING *`,
    [match.id, result, p1New.rating - p1.rating, p2New.rating - p2.rating],
  );
  return rows[0]!;
}
