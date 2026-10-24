// Random tokens and codes. Only their SHA-256 hashes are stored, so a leaked
// database can't be used to log in or reset passwords.
import { createHash, randomBytes, randomInt } from "node:crypto";

export const ACCESS_TOKEN_TTL = "15m";
export const REFRESH_TOKEN_DAYS = 30;
export const RESET_CODE_MINUTES = 15;
export const RESET_CODE_MAX_ATTEMPTS = 5;

export const sha256 = (value: string) => createHash("sha256").update(value).digest("hex");
export const newRefreshToken = () => randomBytes(32).toString("base64url");
export const newResetCode = () => randomInt(0, 1_000_000).toString().padStart(6, "0");
