-- Game-wide switches the admin changes in the portal (Settings page).
CREATE TABLE settings (
  key         text PRIMARY KEY,
  value       jsonb NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
-- New players must confirm their email (6-digit code) before playing.
INSERT INTO settings (key, value) VALUES ('email_verification_required', 'true');
