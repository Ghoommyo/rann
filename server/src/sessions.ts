// Access tokens (short JWTs sent with every request) and refresh tokens
// (long-lived, stored hashed, exchanged for a new pair when the JWT expires).
import type { FastifyInstance } from "fastify";
import type { Queryable } from "./db.js";
import { ACCESS_TOKEN_TTL, REFRESH_TOKEN_DAYS, newRefreshToken, sha256 } from "./auth/tokens.js";

export interface Tokens {
  access_token: string;
  refresh_token: string;
  /** Seconds until access_token expires. */
  expires_in: number;
}

export async function issueTokens(app: FastifyInstance, db: Queryable, userId: string): Promise<Tokens> {
  const refresh = newRefreshToken();
  await db.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES ($1, $2, now() + make_interval(days => $3))`,
    [userId, sha256(refresh), REFRESH_TOKEN_DAYS],
  );
  return { access_token: app.jwt.sign({ sub: userId }, { expiresIn: ACCESS_TOKEN_TTL }), refresh_token: refresh, expires_in: 15 * 60 };
}

export async function revokeAllSessions(db: Queryable, userId: string): Promise<void> {
  await db.query("UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL", [userId]);
}
