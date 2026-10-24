# Rann

A 2.5D fighting game built with Godot 4. Plans and architecture are in [`plans/`](plans/README.md).

## Run
```bash
godot --path .                        # play (starts at the login screen, or the main menu once logged in)
godot --path . --editor               # open in the Godot editor
```

## Controls
| | Move | LP | RP | LK | RK |
|---|---|---|---|---|---|
| P1 keyboard | WASD | U | I | J | K |
| P2 keyboard | Arrows | Num 4 | Num 5 | Num 1 | Num 2 |
| Gamepad | D-pad / left stick | □ / X | △ / Y | ✕ / A | ○ / B |

**Special (SP)** for simple controls: P1 `L`, P2 `Num 6`, gamepad R1, touch "SP". Touch also has **BLK** (block).

Hold **back** to block high/mid, **down-back** to block low.
`Esc` / Start pause · `F1` collision boxes · `F2` touch controls · `F3` frame-data panel · `F5` restart · `Enter` rematch.
Training: `F6` change dummy behaviour · `F7` record / stop (then the dummy plays it back).

## Characters
| | Style | Signature |
|---|---|---|
| **Kael** | Striker, Rage meter | Rage Burst `236+LP+RP` (full meter) |
| **Mira** | Tiger ↔ Crane stances (`LK+RK`), parry (tap forward just before a high/mid hits) | Rising Crane launcher (Crane `RK`) |
| **Tulbul Pandey** | Zoner/counter: long pokes, parry, SWAG meter | Belt Whip `236+RP`, Dabangg Slow-Mo `236+LP+RP` (full meter) |
| **Bogembo** | Boss grappler: charge moves (hold back), KHUSH meter | Unbreakable Tezaab Drop `4+LP+RP`, Henchman Charge `[4]6+RP` |
| **Ravan** | Heavy demon king, long reach, DASHANAN meter | Maya Wave `236+RK`, Dashanan Rage `236+LP+RP` (full meter) |
| **Aswashthama** | Fast rushdown with parry, MANI meter | Astra Rush `236+RP`, Narayanastra `236+LP+RP` (full meter) |

3D models: see [plans/07-guide-mixamo-import.md](plans/07-guide-mixamo-import.md) (Mixamo stock models) and [plans/09-guide-custom-characters.md](plans/09-guide-custom-characters.md) (your own characters from pictures). Until you add them, fighters are capsules.

## Mobile and web builds
`tools/build_mobile.sh android-debug | android-release | ios | web`. See [plans/05-phase-mobile-release.md](plans/05-phase-mobile-release.md) for signing and store steps.

The web build (`build/web/`) runs in any modern browser. Try it locally with
`python3 -m http.server 8000 --directory build/web` and open http://localhost:8000.
Online play isn't available in the browser yet (browsers can't open the direct UDP
connections it uses); everything else is.

## Accounts and ranking
Players can sign up, log in (username or email), reset a forgotten password, edit a
bio, and change their username, email or password from the top-right menu on the
title screen. Online matches between two logged-in players are **ranked** with
Glicko-2 (like chess.com); the profile shows rating, rank and games played/won/lost.
Guests can play everything, unranked.

This needs the server in [`server/`](server/README.md) running (Node + PostgreSQL).
Set its address in **Settings → Server**.

Every fight starts with a 60-second loading screen with room for an ad
(`Game.LOADING_SECONDS`, `Game.LOADING_SKIPPABLE` in `game/game.gd`).

## Online
Main menu → **Online** → pick your fighter → **Host** or **Join** with the host's IP address (port 7777, UDP).
Same Wi-Fi works right away. Over the internet, the host forwards UDP 7777 on their router.
Uses rollback netcode; see [plans/04-phase-online-multiplayer.md](plans/04-phase-online-multiplayer.md).

Testing two accounts on one computer: give each window its own login with `--session`, e.g.
`godot --path . -- --net-host --session=a` and `godot --path . -- --net-join=127.0.0.1 --session=b`
(add `--loading=0` to skip the 60-second loading screen).

## Test
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
cd server && npm test        # the server (needs PostgreSQL, see server/README.md)
```
