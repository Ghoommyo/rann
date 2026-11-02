-- Verified emails, and one table for every emailed 6-digit code.
ALTER TABLE users ADD COLUMN email_verified_at timestamptz;
-- Accounts made before verification existed count as verified.
UPDATE users SET email_verified_at = created_at;

-- One-time codes sent by email. Only a hash of the code is stored.
CREATE TABLE email_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users ON DELETE CASCADE,
  purpose     text NOT NULL CHECK (purpose IN ('verify_email', 'reset_password', 'change_password', 'change_email')),
  code_hash   text NOT NULL,
  new_email   citext,                       -- change_email: the address being confirmed
  attempts    integer NOT NULL DEFAULT 0,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX email_codes_open ON email_codes (user_id, purpose) WHERE used_at IS NULL;

-- Replaced by email_codes (it only ever held 15-minute codes).
DROP TABLE password_resets;
