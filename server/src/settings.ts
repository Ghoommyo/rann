// Game-wide switches the admin changes in the portal (the settings table).
import type { Queryable } from "./db.js";

export interface Settings {
  /** New players must enter the emailed code before they can log in. */
  email_verification_required: boolean;
}

/** Used when a setting has no row yet. */
export const DEFAULT_SETTINGS: Settings = {
  email_verification_required: true,
};

export async function getSettings(db: Queryable): Promise<Settings> {
  const { rows } = await db.query<{ key: string; value: unknown }>("SELECT key, value FROM settings");
  const saved = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return { ...DEFAULT_SETTINGS, ...saved } as Settings;
}

export async function updateSettings(db: Queryable, changes: Partial<Settings>): Promise<Settings> {
  for (const [key, value] of Object.entries(changes)) {
    await db.query(
      `INSERT INTO settings (key, value) VALUES ($1, $2)
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
      [key, JSON.stringify(value)],
    );
  }
  return getSettings(db);
}
