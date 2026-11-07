# Rann server

Accounts, profiles and ranked ratings for Rann. A small Node + TypeScript API
([Fastify](https://fastify.dev)) in front of PostgreSQL. The game never talks
to the database directly: that would put the database password inside the app.

```
game (Android / iOS / web) ──HTTP JSON──► server (Node) ──► PostgreSQL
```

The fights themselves stay peer-to-peer. The server only stores who played
whom and who won, and updates ratings.

## Run it on your Mac

You need Node 22+ and PostgreSQL 17. On this Mac, Postgres runs from **Postgres.app**
(it listens on port 5432; start it from the menu bar).

First time only:
```bash
cd server
npm install
cp .env.example .env            # then set JWT_SECRET: openssl rand -base64 48
/Applications/Postgres.app/Contents/Versions/17/bin/createdb rann_dev
/Applications/Postgres.app/Contents/Versions/17/bin/createdb rann_test
```

Every time:
```bash
cd server
npm run dev                     # http://localhost:8787, restarts when code changes
```
The server creates and updates the tables itself on start (`migrations/*.sql`).

In the game, **Settings → Server** sets the address (default `http://localhost:8787`).
To play from a phone on the same Wi-Fi, use your Mac's address instead, e.g.
`http://192.168.1.14:8787` (the server prints it when it starts).

Without `SMTP_URL` in `.env`, emails (verification and password codes) are printed in
the server's console instead of being sent, so you can copy the codes from there.

## Email (Brevo, free)

The server emails 6-digit codes:
- to confirm a new account's email,
- to reset a forgotten password,
- to change the password,
- and to confirm a new email address.

Codes work for 15 minutes, 5 tries each.

To send real emails, use [Brevo](https://www.brevo.com). Its free plan sends about 300 emails a day, and you don't need your own domain.

1. Create a free Brevo account.
2. **Senders, Domains & Dedicated IPs → Senders → Add a sender**: enter the address
   the codes should come from (e.g. your Gmail), then click the link Brevo emails you.
3. **SMTP & API → SMTP**:
   - Note the **SMTP login**. It looks like `8a1b2c001@smtp-brevo.com`; it's not your email.
   - Click **Generate a new SMTP key** and copy the key.
4. In `server/.env`, write the login with its `@` as `%40`:
   ```
   SMTP_URL=smtp://8a1b2c001%40smtp-brevo.com:YOUR_SMTP_KEY@smtp-relay.brevo.com:587
   MAIL_FROM=Rann <the-sender-you-confirmed@gmail.com>
   ```
5. Check it: `npm run test-email -- your-own@address.com`, then look in your inbox (and spam).
6. Restart the server (`npm run dev`).

`.env` is never committed, so the key stays on your computer. When the server is hosted,
put the same two values in the host's environment variables.

If sending fails, the player sees "Couldn't send the email. Try 'Resend code' in a minute."
The server console shows why.

## Admin portal

A website for managing the game, at **http://localhost:8787/admin** (or `/admin` on the
hosted server). Admin logins are separate from game accounts: an admin can't play, and a
player can't open the portal.

Make your admin login (or change its password) once:
```bash
npm run create-admin -- you@example.com
```
It asks for the password twice. What you type isn't shown, and only a hash is stored.

The top-right menu (☰) has **Dashboard**, **Users**, **Players**, **Settings** and **Log out**:
- **Dashboard**:
  - totals for users and ranked matches
  - charts of sign-ups, matches and players online per day (last 30 days)
  - which fighters are picked most, and the top 10 players
- **Users**:
  - Active and Inactive tabs, and search by username or email
  - **Switch off** logs the player out on every device and stops them logging in
    ("This account has been switched off. Contact support."). **Switch on** undoes it.
  - Inactive users include players who deactivated their own account; they can come back
    by logging in.
- **Players**:
  - Active and Inactive tabs of fighters, each with an on/off switch
  - Only active fighters can be picked; the others show as "?" in character select.
  - The game downloads the list at start-up and whenever character select opens. Offline,
    it uses the last list it got (Kael and Mira on a first launch with no connection).

- **Settings**: **Require email verification** (on for a new server).
  - **On**: new players enter the emailed 6-digit code before they can play.
  - **Off**: sign-up logs them in straight away, and players who never confirmed can log in too.
  - Forgot-password and changing an email or password still use emailed codes either way.

Closing the browser tab logs you out; a login also expires after 8 hours.

**Adding a new fighter to the Players list:** add a migration, e.g. `migrations/005_new_fighter.sql`:
```sql
INSERT INTO fighters (id, name) VALUES ('new_fighter_id', 'Display Name');
```
The id is the fighter's folder name in `data/characters/`. A new fighter starts inactive
until you switch it on.

## Test
```bash
npm test                        # wipes and uses the rann_test database
npm run typecheck
```

## How ranking works

Ratings use **Glicko-2**, the system chess.com uses. Everyone starts at 1500.
A new player's rating moves a lot at first (the profile shows it as `1500?` while
it's still settling) and less as they play more.

Only **online matches between two logged-in players** are ranked:
1. The host opens the match (`POST /matches`) and sends its id to the other player.
2. The other player joins it (`POST /matches/:id/join`).
3. Both report the winner (`POST /matches/:id/result`).
   - Both agree → ratings change.
   - They disagree → "disputed", nothing changes.
   - Only one reports (the other quit or lost connection) → after 3 minutes that
     report counts, so leaving a lost match still loses. This only applies to
     matches the opponent joined, so nobody can be put in a match they never played.

Because fights are peer-to-peer, a determined cheater with a modified game could
still report false results against an opponent who also reports. A server that runs
the fights itself would be needed to stop that completely.

## API

Errors always look like `{"error": "username_taken", "message": "That username is taken.", "field": "username"}`.
`message` is written for players; `field` says which form field it's about.
Endpoints marked 🔒 need `Authorization: Bearer <access_token>`.

| | |
|---|---|
| `POST /auth/signup` | `{username, email, password}` → `{verification_required, username, email}`; emails a code, no login yet. With verification switched off (admin Settings): also tokens + profile, logged in |
| `POST /auth/verify-email` | `{login, code}` → tokens + profile; `login` is a username or email |
| `POST /auth/resend-verification` | `{login}`; always answers OK |
| `POST /auth/login` | `{login, password, reactivate?}`; `email_not_verified` until the email is confirmed |
| `POST /auth/refresh` | `{refresh_token}` → new tokens (the old refresh token stops working) |
| `POST /auth/logout` | `{refresh_token}` |
| `POST /auth/forgot-password` | `{email}`, always answers OK (doesn't reveal who has an account) |
| `POST /auth/reset-password` | `{email, code, new_password}`, logs out all devices (and confirms the email) |
| 🔒 `GET /me`, `PATCH /me` | profile; `{bio}` (300 characters max) |
| 🔒 `PATCH /me/username` | `{username}` |
| 🔒 `PATCH /me/email` | `{email, password}` → emails a code to the **new** address |
| 🔒 `POST /me/email/confirm` | `{code}` → the email changes now |
| 🔒 `POST /me/password/code` | emails a code to the account's address |
| 🔒 `PATCH /me/password` | `{code, new_password}` → new tokens; logs out other devices |
| 🔒 `POST /me/deactivate` | `{password}`; log in with `reactivate: true` to undo |
| `GET /users/:username` | public profile |
| `GET /leaderboard?limit=50` | top players |
| 🔒 `POST /matches`, `POST /matches/:id/join`, `POST /matches/:id/result`, `GET /matches/:id` | ranked matches (see above) |
| `GET /roster` | `{unlocked: [fighter ids]}`: the fighters players can pick |

Admin portal API (`/admin/api`). Everything but `/login` needs an **admin** token; players' tokens are refused there,
and admin tokens are refused everywhere else:

| | |
|---|---|
| `POST /admin/api/login` | `{email, password}` → `{token, email}` (8 hours) |
| `GET /admin/api/stats` | dashboard numbers and 30-day series |
| `GET /admin/api/users?status=active\|inactive&q=&page=` | 50 per page |
| `POST /admin/api/users/:id/disable`, `/enable` | switch an account off / on |
| `GET /admin/api/fighters`, `PATCH /admin/api/fighters/:id` | `{unlocked}` |
| `GET /admin/api/settings`, `PATCH /admin/api/settings` | `{email_verification_required}` |

Access tokens last 15 minutes; refresh tokens last 30 days. Passwords are hashed with
argon2. Login, sign-up, code and password requests are limited per IP.

## Putting it online

Real players need the server on the internet, with HTTPS. Any host that runs
Node with a Postgres database works, e.g. Railway, Render or Fly.io:

1. Create a Postgres database there and copy its connection URL.
2. Deploy this `server/` folder with the build command `npm ci && npm run build`
   and the start command `npm start`.
3. Set the environment variables from `.env.example`: `DATABASE_URL`, a new random
   `JWT_SECRET`, `CORS_ORIGINS` (the web address of the browser version),
   `SMTP_URL` and `MAIL_FROM` (Brevo, see "Email" above).
4. Change `Settings.DEFAULT_API_URL` in `game/settings.gd` to the server's
   `https://` address and rebuild the game.

The web version must use an `https://` server address when the game itself is served
over https (browsers block mixing the two).
