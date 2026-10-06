# Guide — Adding a New Character (and Fight Style)

Use this checklist once Phase 3 is complete. If the architecture is followed, **most new characters need zero code changes**. Only a truly new mechanic requires one new `StyleComponent` script.

> 💡 **Mindset:** a character = *stats* + *moves* + *style* + *art*. The engine already knows how to run any combination of those.

---

## Step 1 — design on paper
- [ ] Name, `id` (lowercase, unique, **never changed later**, because online play and replays use it)
- [ ] Archetype: rushdown, zoner, grappler, stance, counter-hitter, …
- [ ] Which **existing** style components does it use? List them before inventing anything new.
- [ ] Move list in numpad notation, with rough frame data:

  | Command | Name | Level | Startup | On block | Notes |
  |---|---|---|---|---|---|
  | `LP` | Jab | High | 10 | +1 | |
  | `3+RP` | Launcher | Mid | 15 | −13 | launches on hit |
  | `236+RK` | Spinning kick | Mid | 18 | −6 | costs 1 meter for EX version |

> 💡 **Balance hint:** most characters need a fast 10-frame jab, a safe mid poke, a low, a launcher (unsafe on block), a throw and 2–4 specials. Start from Kael's numbers and adjust.

## Step 2 — create the data folder
```
data/characters/<id>/
  character.tres     # New Resource → CharacterDef
  style.tres         # New Resource → FightStyle
  moves/             # one MoveDef .tres per move
  model.glb
  animations.res
  portrait.png
```
- [ ] Duplicate `data/characters/kael/` as a template and rename everything
- [ ] Fill in `CharacterDef`: health, speeds, weight, hurtbox sizes
- [ ] Create each `MoveDef` in the Godot inspector
- [ ] Reuse shared moves from `data/characters/_shared/moves/` (throw, backdash, …)

## Step 3 — configure the fight style
- [ ] In `style.tres`, add the components the character needs and set their exported settings. For example:
  - `StanceComponent`: `stances = ["normal", "drunken"]`, `switch_command = "LP+RP"`
  - `MeterComponent`: `max = 3000`, `gain_on_hit = 100`
- [ ] Stance-only moves: set `MoveDef.required_stance = "drunken"`

## Step 4 (only if needed) — write a new StyleComponent
Do this only if no existing component (or combination) can express the mechanic.
- [ ] Create `core/style/<name>_component.gd` that `extends StyleComponent`
- [ ] Override only the hooks you need (`on_tick`, `can_use_move`, `extra_moves`, `on_hit_landed`, `on_hit_received`)
- [ ] **Store all runtime state in `fighter.style_data` as ints**, using keys prefixed with the component name (e.g. `"poison.stacks"`)
- [ ] No floats, no `randf()`, no timers, no node access
- [ ] If the HUD should show something, expose it via `get_hud_values(fighter) -> Dictionary`
- [ ] Write `tests/style/test_<name>_component.gd`, including a determinism test
- [ ] Document it in a comment at the top of the file: what it does, its settings, its `style_data` keys

> ⚠️ If a new mechanic seems to need changes inside `fighter_sim.gd`, first consider adding a **new generic hook** to `StyleComponent` instead. That way the next character with a similar idea gets it for free.

## Step 5 — art
- [ ] Get the model from Mixamo (or a custom model) and import it with **`SkeletonProfileHumanoid`**
- [ ] Reuse the shared animations (walk, block, hit, knockdown). Add unique ones for signature moves.
- [ ] Name animations to match `MoveDef.animation_name`
- [ ] Portrait for character select; a color palette for alternate costumes (optional)

## Step 6 — verify
- [ ] Run the tests: `test_registry.gd` and `test_character_data.gd` catch missing animations, duplicate ids and broken cancel links
- [ ] Open **Training mode** and check every move with the hitbox and frame-data overlay
- [ ] Play 10+ matches against each existing character, vs CPU and online
- [ ] Bump `game_version`. The data hash changes automatically, so old clients can't match with new ones.

## Done when
- The character appears in character select automatically.
- All moves work with correct frame data.
- Tests and an online match pass with no desync.
