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
- [ ] `FightState.duplicate()` / `restore()` must be fast: target **< 0.2 ms** on a mid-range phone, because up to 8 rollbacks per frame happen
- [ ] A ring buffer of saved states for the last 8–10 frames
- [ ] `FightState.checksum()` is cheap and covers all fields, including `style_data`
- [ ] View must handle "teleports" after rollback: no sounds played twice, effects keyed by `(frame, event)`

### Step 2 — choose a library
- [ ] Prototype with **Delta Rollback** and **netfox** (both Godot 4 addons). Pick the one that fits `match_sim.step()` most cleanly.
  - Fallback: write a small rollback manager ourselves (~400 lines). This is realistic because the sim is already designed for it.

### Step 3 — local network test
- [ ] Two instances on one Mac over ENet (localhost)
- [ ] **Input delay** setting (0–3 frames) first, then full rollback
- [ ] A network simulator: artificial latency, jitter and packet loss
- [ ] **Desync detection:** both peers exchange checksums every ~60 frames. On mismatch, log both states to a file.
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
- [ ] `ui/online_lobby.tscn`: quick match, create/join room, connection status, ping display
- [ ] Rematch / return to lobby
- [ ] Handle disconnects: a 10 s reconnect window, then a win by forfeit
- [ ] Network stats overlay (rollback frames, ping) in debug builds

### Step 6 — hosting
- [ ] Deploy Nakama to a small cloud VM (e.g. DigitalOcean/Hetzner) or Heroic Cloud
- [ ] HTTPS/TLS and a domain; keep server keys out of the game build

### Tests
- [ ] `test_rollback.gd`: simulate 600 frames with delayed, wrong predictions. The final checksum must equal a no-lag run.
- [ ] `test_state_copy.gd`: after `restore()`, every field equals the original (including `style_data`)
- [ ] A manual soak test: 20 matches at 150 ms simulated lag with zero desyncs

## Done when
- Two phones on different networks can quick-match and play a full match that feels responsive at ~100 ms ping, with no desyncs.
