-- Accounts, sessions, password resets and ranked matches.
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username         citext NOT NULL UNIQUE,          -- citext: "Tulbul" and "tulbul" are the same name
  email            citext NOT NULL UNIQUE,
  password_hash    text NOT NULL,
  bio              text NOT NULL DEFAULT '',
  is_active        boolean NOT NULL DEFAULT true,
  -- Glicko-2 rating (the system chess.com uses)
  rating           double precision NOT NULL DEFAULT 1500,
  rating_deviation double precision NOT NULL DEFAULT 350,
  volatility       double precision NOT NULL DEFAULT 0.06,
  games_played     integer NOT NULL DEFAULT 0,
  wins             integer NOT NULL DEFAULT 0,
  losses           integer NOT NULL DEFAULT 0,
  draws            integer NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX users_leaderboard ON users (rating DESC) WHERE is_active AND games_played > 0;

-- Long-lived login sessions. Only a hash of the token is stored.
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- 6-digit codes for "forgot password". Only a hash of the code is stored.
CREATE TABLE password_resets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users ON DELETE CASCADE,
  code_hash   text NOT NULL,
  attempts    integer NOT NULL DEFAULT 0,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Ranked online matches. Each player reports the result; ratings change once
-- the reports agree (or one player reported and the other never did).
CREATE TABLE matches (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player1_id       uuid NOT NULL REFERENCES users,
  player2_id       uuid NOT NULL REFERENCES users,
  p1_character     text NOT NULL DEFAULT '',
  p2_character     text NOT NULL DEFAULT '',
  status           text NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'confirmed', 'disputed', 'expired')),
  result           text CHECK (result IN ('p1', 'p2', 'draw')),
  p1_rating_change double precision,
  p2_rating_change double precision,
  created_at       timestamptz NOT NULL DEFAULT now(),
  resolved_at      timestamptz,
  CHECK (player1_id <> player2_id)
);
CREATE INDEX matches_pending ON matches (created_at) WHERE status = 'pending';

CREATE TABLE match_reports (
  match_id    uuid NOT NULL REFERENCES matches ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES users,
  result      text NOT NULL CHECK (result IN ('p1', 'p2', 'draw')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, reporter_id)
);
