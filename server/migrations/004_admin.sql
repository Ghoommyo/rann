-- The admin portal: admin logins, which fighters players can pick, and
-- accounts switched off by an admin.

-- Admins aren't game players: they only log in to the portal (/admin).
-- Made with `npm run create-admin -- <email>`.
CREATE TABLE admins (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email          citext NOT NULL UNIQUE,
  password_hash  text NOT NULL,
  last_login_at  timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- Every fighter in the game. Players can only pick unlocked ones.
-- A new fighter needs a row here (in a new migration); it starts locked.
CREATE TABLE fighters (
  id          text PRIMARY KEY,                -- the folder name in data/characters/
  name        text NOT NULL,
  unlocked    boolean NOT NULL DEFAULT false,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
INSERT INTO fighters (id, name, unlocked) VALUES
  ('kael', 'Kael', true),
  ('mira', 'Mira', true),
  ('tulbul_pandey', 'Tulbul Pandey', false),
  ('bogembo', 'Bogembo', false),
  ('ravan', 'Ravan', false),
  ('aswashthama', 'Aswashthama', false);

-- Switched off by an admin: like a deactivated account (is_active is false
-- too), but the player can't turn it back on by logging in.
ALTER TABLE users ADD COLUMN disabled_by_admin boolean NOT NULL DEFAULT false;
