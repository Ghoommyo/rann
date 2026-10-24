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

**Forgot password** emails a 6-digit code. Without `SMTP_URL` in `.env`, the email
is printed in the server's console instead, so you can copy the code from there.

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
| `POST /auth/signup` | `{username, email, password}` → tokens + profile |
| `POST /auth/login` | `{login, password, reactivate?}`; `login` is a username or email |
| `POST /auth/refresh` | `{refresh_token}` → new tokens (the old refresh token stops working) |
| `POST /auth/logout` | `{refresh_token}` |
| `POST /auth/forgot-password` | `{email}`, always answers OK (doesn't reveal who has an account) |
| `POST /auth/reset-password` | `{email, code, new_password}`, logs out all devices |
| 🔒 `GET /me`, `PATCH /me` | profile; `{bio}` (300 characters max) |
| 🔒 `PATCH /me/username` | `{username}` |
| 🔒 `PATCH /me/email` | `{email, password}` |
| 🔒 `PATCH /me/password` | `{current_password, new_password}` → new tokens |
| 🔒 `POST /me/deactivate` | `{password}`; log in with `reactivate: true` to undo |
| `GET /users/:username` | public profile |
| `GET /leaderboard?limit=50` | top players |
| 🔒 `POST /matches`, `POST /matches/:id/join`, `POST /matches/:id/result`, `GET /matches/:id` | ranked matches (see above) |

Access tokens last 15 minutes; refresh tokens last 30 days. Passwords are hashed with
argon2. Login, sign-up and password-reset requests are limited per IP.

## Putting it online

Real players need the server on the internet, with HTTPS. Any host that runs
Node with a Postgres database works, e.g. Railway, Render or Fly.io:

1. Create a Postgres database there and copy its connection URL.
2. Deploy this `server/` folder with the build command `npm ci && npm run build`
   and the start command `npm start`.
3. Set the environment variables from `.env.example`: `DATABASE_URL`, a new random
   `JWT_SECRET`, `CORS_ORIGINS` (the web address of the browser version),
   `SMTP_URL` and `MAIL_FROM` from an email provider (e.g. Resend, Postmark, SendGrid).
4. Change `Settings.DEFAULT_API_URL` in `game/settings.gd` to the server's
   `https://` address and rebuild the game.

The web version must use an `https://` server address when the game itself is served
over https (browsers block mixing the two).
