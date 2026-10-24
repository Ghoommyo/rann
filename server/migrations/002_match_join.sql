-- The opponent (player 2) confirms they're really in the match. Without this
-- a host could open matches against anyone and win them by reporting alone.
ALTER TABLE matches ADD COLUMN joined_at timestamptz;
