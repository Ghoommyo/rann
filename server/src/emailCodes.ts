// One-time 6-digit codes sent by email: confirming the address at sign-up,
// resetting or changing the password, and changing the email. Only a hash of
// each code is stored, and each code works once, for a limited time.
import type { Queryable } from "./db.js";
import type { Mailer } from "./mailer.js";
import { ApiError, badRequest } from "./errors.js";
import { RESET_CODE_MAX_ATTEMPTS, RESET_CODE_MINUTES, newResetCode, sha256 } from "./auth/tokens.js";
import type { UserRow } from "./users.js";

export type Purpose = "verify_email" | "reset_password" | "change_password" | "change_email";

const WHY: Record<Purpose, string> = {
  verify_email: "to confirm the email address of your new Rann account",
  reset_password: "to reset your Rann password",
  change_password: "to change your Rann password",
  change_email: "to make this the email address of your Rann account",
};

const codeHash = (userId: string, code: string) => sha256(`${userId}:${code}`);

/**
 * Emails a new code (to the account's address, or `to`). Earlier unused codes
 * for the same purpose stop working. Throws 503 email_failed if it can't send.
 */
export async function sendCode(
  db: Queryable,
  mailer: Mailer,
  user: UserRow,
  purpose: Purpose,
  options: { to?: string; newEmail?: string } = {},
): Promise<void> {
  const code = newResetCode();
  await db.query("UPDATE email_codes SET used_at = now() WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL", [user.id, purpose]);
  await db.query(
    `INSERT INTO email_codes (user_id, purpose, code_hash, new_email, expires_at)
     VALUES ($1, $2, $3, $4, now() + make_interval(mins => $5))`,
    [user.id, purpose, codeHash(user.id, code), options.newEmail ?? null, RESET_CODE_MINUTES],
  );
  try {
    // Plain text with no links or images: the least likely to be marked as spam.
    await mailer.send({
      to: options.to ?? user.email,
      subject: `Your Rann code: ${code}`,
      text:
        `Hi ${user.username},\n\n` +
        `Your code is ${code}. Enter it in the game ${WHY[purpose]}. It expires in ${RESET_CODE_MINUTES} minutes.\n\n` +
        "If you didn't ask for this, you can ignore this email.",
    });
  } catch (err) {
    console.error(`Couldn't send the ${purpose} email:`, err);
    throw new ApiError(503, "email_failed", "Couldn't send the email. Try \"Resend code\" in a minute.");
  }
}

/** Checks a code and uses it up. Returns its new_email (for change_email). */
export async function useCode(db: Queryable, userId: string, purpose: Purpose, code: string): Promise<{ new_email: string | null }> {
  const invalid = () => badRequest("invalid_code", "That code is wrong or has expired. Request a new one.", "code");
  const { rows } = await db.query<{ id: string; code_hash: string; attempts: number }>(
    `SELECT id, code_hash, attempts FROM email_codes
     WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL AND expires_at > now()
     ORDER BY created_at DESC LIMIT 1`,
    [userId, purpose],
  );
  const open = rows[0];
  if (!open || open.attempts >= RESET_CODE_MAX_ATTEMPTS) throw invalid();
  if (open.code_hash !== codeHash(userId, code)) {
    await db.query("UPDATE email_codes SET attempts = attempts + 1 WHERE id = $1", [open.id]);
    throw invalid();
  }
  // `used_at IS NULL` again: two requests racing with the same code can't both win.
  const { rows: used } = await db.query<{ new_email: string | null }>(
    "UPDATE email_codes SET used_at = now() WHERE id = $1 AND used_at IS NULL RETURNING new_email",
    [open.id],
  );
  if (!used[0]) throw invalid();
  return used[0];
}
