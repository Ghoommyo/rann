# Phase 2 — Combat System

**Goal:** real fighting. Attacks with frame data, high/mid/low blocking, throws, combos, health, rounds and a timer, still with capsules. Touch and gamepad controls work too.

> 💡 **Why all moves are data (`MoveDef`):** game designers tune numbers like "startup 10 → 12" hundreds of times. If those numbers live in `.tres` resource files, tuning never touches code and the Godot inspector becomes the move editor. It also means every future character reuses the same combat engine (see [00-architecture.md](00-architecture.md), Rule 4).

---

## Key concepts

### Numpad notation (how inputs are written)
```
7 8 9      ↖ ↑ ↗
4 5 6  =   ← · →      (for a fighter facing right; flipped automatically when facing left)
1 2 3      ↙ ↓ ↘
```
So `236+LP` = down, down-forward, forward + Left Punch (a "quarter-circle forward"). `2+LK` = crouching Left Kick.

### Anatomy of an attack
`startup` is Tekken-style: the frame the hitbox first appears ("i10" hits on frame 10).
```
frames:  1 ........ 9 | 10 11 | 12 ............ 25
         [ startup   ] [active] [ recovery        ]
                        hitbox
                        exists
total = (startup - 1) + active + recovery
```
- **On hit:** the defender enters `hitstun` for N frames.
- **On block:** the defender enters `blockstun` for M frames.
- **Frame advantage** = stun − remaining recovery. This decides whose turn it is after an exchange.

### Blocking rules (Tekken-like)
| Hit level | Stand block | Crouch block |
|---|---|---|
| HIGH | ✅ | ducks under it (whiffs) |
| MID | ✅ | ❌ gets hit |
| LOW | ❌ gets hit | ✅ |
| THROW | break with the correct button within 20 frames | — |

Blocking = holding **back** (`4` or `1`), which is standard for 2.5D games. Mobile also gets a dedicated block button in Phase 5.

---

## Tasks

### Data definitions (`core/defs/`)
- [x] `move_def.gd`: all fields from the architecture doc (command, frame data, hitbox, damage, stun, hit_level, on_hit_effect, cancels_into)
- [x] `character_def.gd`: a minimal version for now (stats + `moves` array). `style` is added in Phase 3.
- [x] A placeholder character `data/characters/dummy/` with ~8 moves: jab, straight, low kick, mid kick, launcher (`3+RP`), sweep (`2+RK`), throw (`LP+LK`) and one special (`236+RP`)

### Input
- [x] `input_buffer.gd`: **motion parser**. It matches command strings such as `236+RP` against the buffer, with a leniency window of about 12 frames.
- [x] Input priority: when several moves match, the most complex command wins (`236+RP` beats `6+RP`, which beats `RP`)
- [x] `input_router.gd`: keyboard + **gamepad** (Godot `Input` joypad) → `InputFrame`
- [x] Basic **touch controls** (`ui/touch_controls.tscn`): virtual stick + 4 buttons. Final polish comes in Phase 5.

### Combat logic (`core/`)
- [x] `fighter_sim.gd`: add states `ATTACK, HITSTUN, BLOCKSTUN, THROWN, KNOCKDOWN, WAKEUP, LAUNCHED (juggle)`
- [x] Hit resolution in `match_sim.gd`: an active hitbox overlapping a hurtbox → check block → apply damage, stun and pushback
- [x] Each move hits at most once per activation (no multi-hit bugs)
- [x] Trades: both fighters hit on the same frame → both take damage
- [x] Cancels: during the hit/block window, `cancels_into` moves can interrupt recovery → combos
- [x] Juggle: a launcher puts the opponent airborne. Gravity scaling limits infinite combos.
- [x] **Damage scaling**: each extra hit in a combo does less damage (100%, 90%, 80% … down to 30%)
  > 💡 Without scaling, one combo could take a full health bar and matches would feel unfair.
- [x] Rounds: KO or time-out (99 s = 5940 frames) → round end → reset → best of 3

### View / feedback
- [x] Hitbox overlay: draw hitboxes in red and hurtboxes in green
- [x] **Hitstop:** freeze both fighters for 6–10 frames on hit (this stays deterministic because it is part of the sim)
  > 💡 Hitstop is the tiny pause that makes hits feel heavy. It matters a lot for "game feel".
- [x] A simple debug HUD: health numbers, current state, frame advantage readout

### Tests
- [x] `test_motion_parser.gd`: `236` is detected; a sloppy `2 → 3 → 6` within leniency still works; a too-slow input fails
- [x] `test_frame_data.gd`: a jab hits exactly on frame `startup` (i10 = frame 10)
- [x] `test_blocking.gd`: the full high/mid/low/throw table above
- [x] `test_combo.gd`: jab → straight cancel connects; damage scaling applied
- [x] `test_determinism.gd` (extended): random fights with attacks still give identical checksums

## Done when
- Two players can play a full best-of-3 match with capsules, using keyboard, gamepad or touch.
- Blocking feels correct and combos work.
- All tests pass.

---

## Status: ✅ complete (2026-10-06)
66 tests and 1037 asserts pass. Determinism holds over 3000 random frames that include attacks, KOs and round changes.

**What was built**
- `core/defs/move_def.gd`, `core/move_command.gd` (parser), `core/combat.gd` (hits, blocks, throws), `core/rules.gd` (game-wide numbers)
- Dummy character with 8 moves in `data/characters/dummy/moves/*.tres`:

  | Move | Command | Level | Startup | On hit | On block |
  |---|---|---|---|---|---|
  | Jab | `LP` | High | i10 | +8 | +1 (cancels into Straight) |
  | Straight | `RP` | High | i12 | +6 | −2 |
  | Mid Kick | `RK` | Mid | i14 | +2 | −9 |
  | Low Kick | `2+LK` | Low | i12 | +2 | −12 |
  | Sweep | `2+RK` | Low | i18 | knockdown | −23 |
  | Launcher | `3+RP` | Mid | i15 | launch | −13 |
  | Dashing Punch | `236+RP` | Mid | i16 | +3 | −9 |
  | Throw | `LP+LK` | Throw | i12 | 120 dmg, break with `LP` | — |
- Gamepad (P1 = first pad, P2 = second; □△✕○ = LP RP LK RK) and touch controls (on by default on phones, F2 on desktop)
- Simple HUD (`ui/fight_hud.gd`): health bars, timer, round wins, round messages, and a debug panel showing frame advantage

**Changes from the plan**
- Added a `WAKEUP` state after `KNOCKDOWN`, so getting up has its own animation slot in Phase 3. Both states are invincible.
- Rounds use a `Phase` enum in `FightState`: READY → FIGHTING → ROUND_OVER → MATCH_OVER. A drawn round gives both players a win.
- Air attacks aren't included yet. The data supports adding them later.
