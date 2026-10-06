# Phase 4 — Online Multiplayer (Rollback Netcode)

**Goal:** two players on different devices can find each other and play a smooth online match, even with ~100–150 ms of latency.

---

## How rollback works (read this first)

> 💡 **The problem:** an opponent's input takes time (e.g. 80 ms ≈ 5 frames) to reach you over the internet. Waiting for it would make the game feel laggy.
>
> **The rollback solution:**
> 1. Each frame, send only your **input** (one small int), not the game state.
> 2. If the opponent's input for this frame hasn't arrived, **predict** it (usually "same as last frame").
> 3. Run the frame immediately with the prediction. The game feels instant.
> 4. When the real input arrives and differs from the prediction, **rewind** to that frame (load the saved `FightState`), then **replay** every frame up to now with the corrected input. This all happens within one rendered frame.
>
> This only works because Phases 1–3 made the simulation **deterministic** and **copyable** (`FightState.duplicate()`). That is why those rules exist.

```
frame:     100   101   102   103   104 (now)
saved:     S100  S101  S102  S103
P2 input:  real  pred  pred  pred  pred
                  ↑ real input for 101 arrives and differs
→ load S101, re-simulate 101..104 with corrected input, continue
```

---

## Tasks

### Step 1 — netcode foundation
- [x] `FightState.duplicate()` / `restore()` must be fast: target **< 0.2 ms** on a mid-range phone, because up to 8 rollbacks per frame happen
- [x] A ring buffer of saved states for the last 8–10 frames
- [x] `FightState.checksum()` is cheap and covers all fields, including `style_data`
- [x] View must handle "teleports" after rollback: no sounds played twice, effects keyed by `(frame, event)`

### Step 2 — choose a library
- [ ] Prototype with **Delta Rollback** and **netfox** (both Godot 4 addons). Pick the one that fits `match_sim.step()` most cleanly.
  - Fallback: write a small rollback manager ourselves (~400 lines). This is realistic because the sim is already designed for it.

### Step 3 — local network test
- [x] Two instances on one Mac over ENet (localhost)
- [x] **Input delay** setting (0–3 frames) first, then full rollback
- [x] A network simulator: artificial latency, jitter and packet loss
- [x] **Desync detection:** both peers exchange checksums every ~60 frames. On mismatch, log both states to a file.
  > 💡 Desync logs are gold: they show exactly which field differed, usually a float or an uncopied variable that sneaked into the sim.

### Step 4 — matchmaking server (Nakama)
- [ ] Run Nakama locally with Docker (`docker compose up`)
- [ ] Add the Nakama Godot client (`addons/com.heroiclabs.nakama`)
- [ ] Device-ID auth (no signup needed), then optional accounts later
- [ ] Quick match (matchmaker) + private room by code
- [ ] Transport: Nakama relayed match data first (simple and works behind any NAT). WebRTC peer-to-peer can be added later for lower latency.
- [ ] Before a match, both players exchange `game_version`, `character ids` and a **data hash** of their `MoveDef`s. If they differ → refuse the match.
  > 💡 If one player has an older balance patch, their simulations would disagree. The hash catches that.

### Step 5 — UX
- [x] `ui/online_lobby.tscn`: quick match, create/join room, connection status, ping display
- [x] Rematch / return to lobby
- [ ] Handle disconnects: a 10 s reconnect window, then a win by forfeit
- [x] Network stats overlay (rollback frames, ping) in debug builds

### Step 6 — hosting
- [ ] Deploy Nakama to a small cloud VM (e.g. DigitalOcean/Hetzner) or Heroic Cloud
- [ ] HTTPS/TLS and a domain; keep server keys out of the game build

### Tests
- [x] `test_rollback.gd`: simulate 600 frames with delayed, wrong predictions. The final checksum must equal a no-lag run.
- [x] `test_state_copy.gd`: after `restore()`, every field equals the original (including `style_data`)
- [ ] A manual soak test: 20 matches at 150 ms simulated lag with zero desyncs

## Done when
- Two phones on different networks can quick-match and play a full match that feels responsive at ~100 ms ping, with no desyncs.

---

## Status: ✅ rollback + direct connect done (2026-10-06). Matchmaking (Steps 4 and 6) is next.
109 tests pass. A real-network soak test (two game processes over ENet on localhost, CPU bots, 150 ms added lag, 3000 frames) gave **identical checksums with no desync**. The worst rollback (restore + 8 frames) costs about 0.15 ms on a Mac.

**What was built**
- `net/rollback_session.gd`: input delay (0–3, host decides), prediction, a ring buffer of saved states, rollback and re-simulation, stalling beyond 8 frames, events shown only once, a checksum exchange every 60 frames, and a desync report in `user://desync_<frame>.txt`
- `net/net_messages.gd`: HELLO / START / INPUT / CHECKSUM / PING / PONG / REMATCH / BYE. `INPUT` and `CHECKSUM` carry a match number, so rematches never mix
- `net/enet_transport.gd`: direct UDP connection on port **7777**, plus a lag simulator
- `net/sim_transport.gd`: an in-memory network with latency, jitter and loss, for the tests
- `net/online_connection.gd`: the handshake. It checks `Game.GAME_VERSION` and `core/data_hash.gd`, a fingerprint of all gameplay data
- Online lobby (`ui/menus/online_lobby.gd`), rematch, disconnect and timeout (10 s) handling, and net stats in the F3 panel

**Changes from the plan**
- **The rollback manager is our own code (~250 lines)**, not the Delta Rollback or netfox addons. The simulation was already built for rollback, so this was simpler, needed no dependencies, and is fully tested.
- **Nakama (matchmaking + relay) is postponed** until Docker or a server is available. Until then, the host shares their IP address. On the same Wi-Fi that just works; over the internet, the host must forward **UDP port 7777** on their router.
- Rematch is in the code, but no automated test covers it yet.

**Testing online play yourself**
```bash
# Two windows on one Mac:
godot --path . -- --net-host
godot --path . -- --net-join=127.0.0.1 --net-lag=100      # adds 100 ms lag to test rollback
# Automated soak (prints NET_RESULT lines with checksums that must match):
godot --headless --path . -- --net-host --net-bot --net-frames=3000
godot --headless --path . -- --net-join=127.0.0.1 --net-bot --net-lag=150 --net-frames=3000
```

**Still to do for Phase 4**
- [ ] Step 4: Nakama matchmaking + relay (needs Docker Desktop: `brew install --cask docker`)
- [ ] Step 6: host the server online
- [ ] A rematch test over the simulated network
