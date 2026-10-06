# Phase 3 — Characters, Fight Styles, Visuals & CPU

**Goal:** the game looks and feels like a real fighting game. It has **2 distinct characters with different fight styles**, a 3D stage, a HUD, effects, sound, a CPU opponent and menus.

This is the phase where the **scalable character system** from [00-architecture.md](00-architecture.md) gets built. The two starting characters are chosen to test it: they must play very differently while sharing the same engine.

---

## Starting roster (proposal)

| | **Kael** — "Striker" | **Mira** — "Stance dancer" |
|---|---|---|
| Archetype | Straightforward rushdown | Tricky, mix-up heavy |
| Style components | `MeterComponent` ("Rage", spent on a super) | `StanceComponent` (Tiger ↔ Crane), `ParryComponent` |
| Signature | Strong pressure, `236+RP` dashing punch | Each stance has its own move set; parry on `6` timing |
| Purpose for the codebase | Proves meter + super moves | Proves stances + extra moves + hit-cancelling hooks |

> 💡 **Why these two?** If two very different styles both work using only data + components, the system is proven to scale. Character #3 onward is then mostly content work (see [06-guide-adding-a-character.md](06-guide-adding-a-character.md)).

---

## Tasks

### Character system (`core/`)
- [ ] `core/defs/character_def.gd`: complete version (stats, hurtboxes per posture, model, animation library, portrait, moves, style)
- [ ] `core/defs/fight_style.gd`: holds `components: Array[StyleComponent]`
- [ ] `core/style/style_component.gd`: base class with the hooks from the architecture doc
- [ ] Connect the hooks into `fighter_sim.gd` / `match_sim.gd` at fixed points (`on_tick`, `can_use_move`, `extra_moves`, `on_hit_landed`, `on_hit_received`)
- [ ] `FighterState.style_data`: a `Dictionary` of **ints only**, copied by `duplicate()` and included in `checksum()`
- [ ] Components: `meter_component.gd`, `stance_component.gd`, `parry_component.gd`, `charge_input_component.gd` (unused by the first two, but built and tested to prove the API)
- [ ] `core/character_registry.gd` (autoload): scans `data/characters/*/character.tres` and looks characters up by `id`
- [ ] Move `dummy` to a test-only fixture. Build `kael/` and `mira/` data folders.

### Art pipeline
- [ ] Download 2 characters + animations from **Mixamo** (FBX, "without skin" for animation-only files)
- [ ] Convert to GLB (Blender) and import into Godot with **`SkeletonProfileHumanoid`** retargeting
- [ ] Build `animations.res` (AnimationLibrary) per character. Put shared animations (walk, block, hit reactions, knockdown) in `data/characters/_shared/`.
- [ ] Naming convention: the animation name = the `MoveDef.animation_name` (e.g. `kael_rising_uppercut`)
  > 💡 A consistent naming convention is what lets the view find the right animation without any per-character code.

### View
- [ ] `fighter_view.gd`: loads the model from `CharacterDef`, plays the animation for the current state/move and **seeks to `state_frame / 60.0`**
  > 💡 The animation is a *slave* to the simulation: it doesn't decide anything, it just shows "frame 7 of the uppercut". After a rollback it jumps to the right pose instantly.
- [ ] `camera_rig.gd`: keeps both fighters in view, zooms out when they're far apart, adds small shake on big hits
- [ ] One stage: a ground plane, a backdrop, lighting tuned for the Mobile renderer, and invisible walls
- [ ] Effects: hit sparks (different for block and hit), a dust cloud on landing, a super-move flash
- [ ] Sound: hit/block/whiff SFX, KO voice and music. Sounds are triggered by sim **events** (`state.events` list per tick).
- [ ] `ui/hud.tscn`: health bars (with a "recent damage" trail), timer, round pips, a style meter area (generic: shows whatever the components expose)

### CPU opponent (`ai/cpu_opponent.gd`)
- [ ] It produces `InputFrame`s like a human would, so it uses the same code path
- [ ] Difficulty levels: reaction delay (e.g. 25 / 15 / 8 frames), block chance, combo knowledge
- [ ] Simple behaviour tree: approach → poke → block when the opponent attacks → punish unsafe moves (it reads `MoveDef` frame data)
- [ ] Randomness comes from the seeded RNG in `FightState` (deterministic)

### Menus & flow
- [ ] `main_menu.tscn`: Versus CPU, Local Versus, Online (disabled until Phase 4), Training, Settings
- [ ] `character_select.tscn`: built from `CharacterRegistry` (no hard-coded list)
- [ ] **Training mode**: infinite health, hitbox display, frame-data display, a dummy that records and plays back inputs
  > 💡 Training mode is also your best debugging tool for balancing new characters.

### Tests
- [ ] One test file per style component (stance switching, meter gain/spend, parry window, charge timing)
- [ ] `test_registry.gd`: all characters load; ids are unique; every `MoveDef.animation_name` exists in the library
- [ ] `test_character_data.gd`: data validation (e.g. no move has 0 active frames; cancels point to existing moves)
- [ ] Determinism test with Kael vs Mira using all components

## Done when
- You can play Kael vs Mira (vs CPU or locally) on a real stage with animations, sound and a HUD.
- Both characters clearly play differently.
- No character-specific `if` statements exist anywhere in `core/` or `view/`.
