# 00 — Architecture

This file explains **how the game is put together**. Every phase builds on these rules, so read this first.

---

## Rule 1: split "simulation" from "view"

```
        ┌───────────────────────────── 60 ticks/sec ──────────────────────────────┐
Input ──►  CORE SIMULATION (core/)                                                │
(touch,  │  • pure GDScript, integer math only                                    │
 pad,    │  • FightState = positions, health, timers, current moves…              │
 net)    │  • step(state, input_p1, input_p2) -> new state                        │
        └───────────────────────────────┬─────────────────────────────────────────┘
                                        │ read-only
                                        ▼
        ┌──────────────────────────── every rendered frame ────────────────────────┐
        │  VIEW (view/)                                                            │
        │  • 3D models, animations, particles, camera, sound, HUD                  │
        │  • never changes game state, only draws it                               │
        └──────────────────────────────────────────────────────────────────────────┘
```

> 💡 **Why:** online play rewinds and replays the simulation several times a second. If game logic lived in 3D nodes, animations or physics, it couldn't be rewound cleanly. Keeping all logic in plain data that can be copied and restored makes rollback possible. It also makes the logic easy to unit test.

**In practice:**
- `core/` never uses `Node3D`, `AnimationPlayer`, `PhysicsBody`, `Time`, `randf()` or `float`.
- `view/` reads `FightState` and makes things look nice. If the view is deleted, the game still "plays" correctly, just invisibly. That is how the tests run.

---

## Rule 2: fixed 60 Hz tick

The simulation advances in exact steps of one frame (1/60 s), never by "delta time".

> 💡 **Why:** with variable delta time, a fast phone and a slow phone would compute slightly different results. Fixed steps mean "frame 120" is identical on every device. Fighting-game frame data ("this punch has 10 frames of startup") also only makes sense with fixed frames.

Godot setting: `physics/common/physics_ticks_per_second = 60`. The match loop runs in `_physics_process`, and the view interpolates in `_process`.

---

## Rule 3: integer math only in the simulation

- Positions are stored as **integers in milli-units** (`1000 = 1 meter`). Speeds are milli-units per frame.
- No `float`, no `sin/cos`, no `sqrt` inside `core/`. Helpers live in `core/fixed_math.gd`.
- Randomness (for example CPU decisions that affect the sim) uses a seeded integer RNG stored **inside** `FightState`.

> 💡 **Why:** floating-point math can give slightly different results on different CPUs, such as an ARM phone and an x86 PC. Tiny differences grow over time, and online the two players would end up seeing different fights (a desync). Integers are exact everywhere.

---

## Rule 4: everything about a character is data

Adding a character should mean **adding files to `data/characters/`**, not editing engine code.

```
data/
  characters/
    _shared/                 # moves and animations every fighter can use
      moves/  basic_throw.tres, backdash.tres …
    kael/                    # one folder per fighter
      character.tres         # CharacterDef
      moves/                 # MoveDef .tres files
        jab.tres  low_kick.tres  rising_uppercut.tres …
      style.tres             # FightStyle (list of components + settings)
      model.glb              # 3D model (shared humanoid skeleton)
      animations.res         # AnimationLibrary
      portrait.png
    mira/
      …
```

### The building blocks

```
CharacterDef (Resource)                     ← "who is this fighter?"
├── id: "kael"            display_name: "Kael"
├── max_health, walk_speed, dash_speed, jump_arc, weight
├── hurtboxes: {standing, crouching, airborne}
├── model_scene, animation_library, portrait
├── moves: Array[MoveDef]                   ← regular moves (from moves/ folder)
└── style: FightStyle                       ← unique mechanics

MoveDef (Resource)                          ← "what does one attack do?"
├── id, display_name, animation_name
├── command: "236+LP"                       ← input that triggers it
├── required_state: STANDING | CROUCHING | AIRBORNE | ANY
├── required_stance: ""                     ← used by stance-based styles
├── startup, active, recovery               ← frame data
├── hitbox (offset + size, in milli-units)
├── damage, hitstun, blockstun, pushback
├── hit_level: HIGH | MID | LOW | THROW     ← what blocks it
├── on_hit_effect: NONE | LAUNCH | KNOCKDOWN | WALL_BOUNCE
├── cancels_into: Array[String]             ← move ids (combos)
└── meter_gain, meter_cost

FightStyle (Resource)                       ← "what makes this fighter unique?"
└── components: Array[StyleComponent]

StyleComponent (base class, deterministic)  ← one pluggable mechanic
├── StanceComponent        (e.g. switch between "Tiger" and "Crane" stance)
├── ChargeInputComponent   (hold back 30 frames, then forward + punch)
├── MeterComponent         (build a "Rage" meter, spend it on super moves)
├── ParryComponent         (tap forward at the right moment to parry)
└── … add new ones as the roster grows
```

### How a component plugs in

Every `StyleComponent` can override a small set of **hooks**, which the core state machine calls at fixed points each tick:

```gdscript
# core/style/style_component.gd  (sketch)
class_name StyleComponent
extends Resource

# Called once when the match starts. Put this component's per-fighter
# data (e.g. current stance, charge counter) into `fighter.style_data`
# so it is part of FightState and gets saved/restored by rollback.
func init_state(fighter: FighterState) -> void: pass

# Called every tick before moves are chosen. Update counters here.
func on_tick(fighter: FighterState, input: InputBuffer) -> void: pass

# Can this move be used right now? (e.g. stance or meter requirements)
func can_use_move(fighter: FighterState, move: MoveDef) -> bool: return true

# Lets a component offer extra moves (e.g. stance-only moves).
func extra_moves(fighter: FighterState) -> Array[MoveDef]: return []

# React to hits (e.g. gain meter, trigger a parry).
func on_hit_landed(fighter: FighterState, move: MoveDef) -> void: pass
func on_hit_received(fighter: FighterState, move: MoveDef) -> bool: return false # true = cancel the hit (parry)
```

> 💡 **Why components instead of one script per character?** With 20 characters, 20 scripts that each copy and tweak the state machine become impossible to balance or debug. Components are small, tested once and reused. Two characters with stances share `StanceComponent` and only differ in data. A truly new mechanic means writing **one** new component, and nothing else changes.

> ⚠️ **The one hard rule for components:** they may only store state in `fighter.style_data` (part of `FightState`) and must follow the integer-only rules. Otherwise rollback breaks.

### CharacterRegistry

`core/character_registry.gd` is an autoload. At startup it scans `data/characters/*/character.tres` and builds `{id → CharacterDef}`.
- Character select lists whatever the registry finds, so new fighters appear automatically.
- Netcode and replays refer to characters by **`id` string**, never by array index. Adding a fighter then doesn't break old replays or online compatibility checks.

### Shared skeleton

Every character model uses Godot's **`SkeletonProfileHumanoid`** (set in the GLB import settings). Any animation can then be retargeted onto any character. A new character can borrow the shared walk, block and hit-reaction animations and only needs new animations for its signature moves.

---

## Full folder layout

```
rann/
  project.godot
  plans/                      # ← you are here
  core/                       # deterministic simulation (no visuals)
    fixed_math.gd
    input_frame.gd            # pack/unpack one frame of input into an int
    input_buffer.gd           # last ~30 frames of input + motion parser
    fight_state.gd            # whole match state; duplicate()/checksum()
    fighter_state.gd          # one fighter's state (pos, vel, health, move, frame, style_data)
    fighter_sim.gd            # state machine: idle/walk/crouch/jump/attack/hitstun/blockstun/knockdown
    collision.gd              # AABB overlap tests (hitbox vs hurtbox, pushboxes)
    match_sim.gd              # step(): runs both fighters, resolves hits, rounds, timer
    character_registry.gd     # autoload
    defs/
      character_def.gd
      move_def.gd
      fight_style.gd
    style/
      style_component.gd
      stance_component.gd
      charge_input_component.gd
      meter_component.gd
      parry_component.gd
  data/characters/…           # see above
  view/
    fighter_view.gd           # model + AnimationPlayer driven by FighterState
    stage_view.gd
    camera_rig.gd
    effects/                  # hit sparks, screen shake
    debug/hitbox_overlay.gd   # draws boxes when debug is on
  ui/
    hud.tscn                  # health, timer, rounds, meters
    touch_controls.tscn
    main_menu.tscn  character_select.tscn  online_lobby.tscn
  input/
    input_router.gd           # keyboard / gamepad / touch → InputFrame
  ai/
    cpu_opponent.gd           # produces InputFrames like a player would
  net/                        # Phase 4
  scenes/
    fight.tscn
  tests/                      # GUT tests (mostly for core/)
  addons/                     # gut, netcode addon, nakama client
```

---

## Data flow for one tick

```
1. input_router (or cpu_opponent, or network) → InputFrame for P1 and P2
2. match_sim.step(state, in1, in2):
     a. push inputs into each fighter's InputBuffer
     b. each StyleComponent.on_tick()
     c. fighter_sim picks the next action (move parser + can_use_move)
     d. advance movement, apply pushboxes, keep fighters on stage
     e. check hitboxes vs hurtboxes → apply damage / stun / effects
     f. update round timer, check KO / time-out
3. state.frame += 1
4. view reads state and draws (interpolating between ticks)
```
