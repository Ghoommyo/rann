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
```
frames:  1 ........ 10 | 11 .. 13 | 14 ............ 30
         [ startup   ] [ active  ] [ recovery         ]
                         hitbox
                         exists
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
- [ ] `move_def.gd`: all fields from the architecture doc (command, frame data, hitbox, damage, stun, hit_level, on_hit_effect, cancels_into)
- [ ] `character_def.gd`: a minimal version for now (stats + `moves` array). `style` is added in Phase 3.
- [ ] A placeholder character `data/characters/dummy/` with ~8 moves: jab, straight, low kick, mid kick, launcher (`3+RP`), sweep (`2+RK`), throw (`LP+LK`) and one special (`236+RP`)

### Input
- [ ] `input_buffer.gd`: **motion parser**. It matches command strings such as `236+RP` against the buffer, with a leniency window of about 12 frames.
- [ ] Input priority: when several moves match, the most complex command wins (`236+RP` beats `6+RP`, which beats `RP`)
- [ ] `input_router.gd`: keyboard + **gamepad** (Godot `Input` joypad) → `InputFrame`
- [ ] Basic **touch controls** (`ui/touch_controls.tscn`): virtual stick + 4 buttons. Final polish comes in Phase 5.

### Combat logic (`core/`)
- [ ] `fighter_sim.gd`: add states `ATTACK, HITSTUN, BLOCKSTUN, THROWN, KNOCKDOWN, WAKEUP, LAUNCHED (juggle)`
- [ ] Hit resolution in `match_sim.gd`: an active hitbox overlapping a hurtbox → check block → apply damage, stun and pushback
- [ ] Each move hits at most once per activation (no multi-hit bugs)
- [ ] Trades: both fighters hit on the same frame → both take damage
- [ ] Cancels: during the hit/block window, `cancels_into` moves can interrupt recovery → combos
- [ ] Juggle: a launcher puts the opponent airborne. Gravity scaling limits infinite combos.
- [ ] **Damage scaling**: each extra hit in a combo does less damage (100%, 90%, 80% … down to 30%)
  > 💡 Without scaling, one combo could take a full health bar and matches would feel unfair.
- [ ] Rounds: KO or time-out (99 s = 5940 frames) → round end → reset → best of 3

### View / feedback
- [ ] Hitbox overlay: draw hitboxes in red and hurtboxes in green
- [ ] **Hitstop:** freeze both fighters for 6–10 frames on hit (this stays deterministic because it is part of the sim)
  > 💡 Hitstop is the tiny pause that makes hits feel heavy. It matters a lot for "game feel".
- [ ] A simple debug HUD: health numbers, current state, frame advantage readout

### Tests
- [ ] `test_motion_parser.gd`: `236` is detected; a sloppy `2 → 3 → 6` within leniency still works; a too-slow input fails
- [ ] `test_frame_data.gd`: a jab hits exactly on frame `startup + 1`
- [ ] `test_blocking.gd`: the full high/mid/low/throw table above
- [ ] `test_combo.gd`: jab → straight cancel connects; damage scaling applied
- [ ] `test_determinism.gd` (extended): random fights with attacks still give identical checksums

## Done when
- Two players can play a full best-of-3 match with capsules, using keyboard, gamepad or touch.
- Blocking feels correct and combos work.
- All tests pass.
