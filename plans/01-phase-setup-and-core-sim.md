# Phase 1 — Setup & Core Simulation

**Goal:** a Godot project where two placeholder capsules walk, crouch, jump and push each other on a flat stage. It's driven by a deterministic 60 Hz simulation and covered by tests.

> 💡 **Why start with ugly capsules?** The "feel" of a fighting game comes from movement and timing, not graphics. Getting the invisible core right first (fixed ticks, integer math, sim/view split) is what makes every later phase, especially online play, possible. Models are easy to swap in later.

---

## Prerequisites
- [x] Install Godot 4.x: `brew install --cask godot`
- [x] Install the GUT addon (from the Godot AssetLib) into `addons/gut/`

## Tasks

### Project setup
- [x] Create `project.godot` (Forward+ or Mobile renderer; **Mobile** recommended for phones)
- [x] Set `physics_ticks_per_second = 60` and `max_physics_steps_per_frame = 8`
- [x] Keyboard bindings, registered in code by `input/input_router.gd`: P1 = WASD + `U I J K`, P2 = arrows + numpad `4 5 1 2`
- [x] Create the folders from [00-architecture.md](00-architecture.md)
- [x] `git init`, plus a `.gitignore` for `.godot/`

### Core simulation (`core/`)
- [x] `fixed_math.gd`: `clamp`, `sign`, `abs`, `lerp_int`, constants such as `UNIT = 1000`
- [x] `input_frame.gd`: pack 8 directions + 4 buttons into one `int`
  > 💡 One int per frame per player is tiny to store and to send over the network, and it's easy to compare.
- [x] `input_buffer.gd`: ring buffer of the last 30 frames (the motion parser comes in Phase 2)
- [x] `fighter_state.gd`: `pos_x, pos_y, vel_x, vel_y, facing, state, state_frame, health, style_data`
- [x] `fighter_sim.gd`: states `IDLE, WALK_F, WALK_B, CROUCH, JUMP_SQUAT, AIRBORNE, LANDING`
  > 💡 A **state machine** means a fighter is always in exactly one state, and each state decides which inputs it accepts and which state comes next. It's the backbone of every fighting game.
- [x] `collision.gd`: integer AABB overlap; pushbox separation so fighters can't overlap
- [x] `fight_state.gd`: two fighters + `frame` + stage bounds; `duplicate()` and `checksum()`
- [x] `match_sim.gd`: `step(state, in1, in2)`, following the "data flow for one tick" in the architecture doc
- [x] Auto-facing: fighters always turn to face each other

### View (`view/`)
- [x] `fight.tscn`: flat ground, light and side camera
- [x] `fighter_view.gd`: capsule mesh whose position comes from `FighterState` (milli-units → meters)
- [x] Interpolate the visual position between ticks for smooth movement on 90/120 Hz screens
- [x] `debug/hitbox_overlay.gd`: draw pushboxes and hurtboxes, toggled with F1

### Tests (`tests/`)
- [x] `test_fixed_math.gd`
- [x] `test_input_frame.gd`: pack/unpack round-trip
- [x] `test_movement.gd`: holding forward for 60 frames moves exactly `walk_speed * 60`
- [x] `test_pushbox.gd`: walking into the opponent never overlaps
- [x] **`test_determinism.gd`**: run 1000 frames of random (seeded) input twice and get the same checksum

## Files created
`project.godot`, `core/*.gd`, `view/fighter_view.gd`, `view/debug/hitbox_overlay.gd`, `scenes/fight.tscn`, `tests/*.gd`

## Done when
- Two players on one keyboard can walk, crouch, jump and push each other.
- Debug boxes line up with the capsules.
- All tests pass headless.

## How to test
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
godot --path . scenes/fight.tscn
```

---

## Status: ✅ complete (2026-10-06)
- Godot 4.7.2, GUT 9.7.1. 26 tests and 898 asserts pass, including determinism over 1000 random frames.
- **Change from the plan:** `core/defs/character_def.gd` was added now, holding only movement and body stats, so no fighter numbers are hard-coded in `core/`. Phase 2 adds moves to it.
- Test helpers live in `tests/helpers.gd`. Character data is in `data/characters/dummy/character.tres`.
