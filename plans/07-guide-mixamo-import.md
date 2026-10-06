# Guide — Getting Characters from Mixamo into Rann

This replaces the capsules with real 3D fighters. You download the files and a tool script does the rest: no Blender and no Godot import settings needed.

> 💡 **Why Mixamo works so well here:** every Mixamo character uses the same skeleton, so any Mixamo animation plays on any Mixamo character. Godot 4.3+ also imports `.fbx` files directly.

---

## 1. Download (free Adobe account: https://www.mixamo.com)

### The model (once per character)
1. **Characters** tab → pick a character. Suggestions: something heavier for **Kael**, something lighter or more agile for **Mira**.
2. Click **Download** with these settings: Format **FBX Binary (.fbx)**, Pose **T-pose**.
3. Save it as `assets/characters/<id>/model.fbx`, where `<id>` is `kael` or `mira`.

### The animations
With your character selected, open the **Animations** tab, search for each one below, then **Download** with: Format **FBX Binary**, Skin **Without Skin**, Frames per second **30**. For walk animations, tick **In Place** if it's offered.

Save each file into `assets/characters/<id>/anims/` and **rename it to the exact name in the first column**. The file name becomes the animation name the game looks for.

#### Shared animations (both characters need these)
| File name | Search Mixamo for | Notes |
|---|---|---|
| `idle.fbx` | "fighting idle" / "boxing idle" | loops |
| `walk_forward.fbx` | "fight walk forward" / "boxing step forward" | loops, In Place |
| `walk_back.fbx` | "walk backward" / "boxing step back" | loops, In Place |
| `crouch.fbx` | "crouch idle" | loops |
| `jump.fbx` | "jump" | |
| `land.fbx` | "landing" | |
| `hit.fbx` | "head hit" / "hit reaction" | |
| `block.fbx` | "center block" / "body block" | |
| `juggle.fbx` | "flying back" / "falling back death" | launched in the air |
| `knockdown.fbx` | "knocked down" / "dying" | ends lying down |
| `wakeup.fbx` | "getting up" / "stand up" | |
| `thrown.fbx` | "being thrown" / "falling" | |

#### Kael's moves (`assets/characters/kael/anims/`)
| File name | Search Mixamo for |
|---|---|
| `jab.fbx` | "lead jab" |
| `straight.fbx` | "cross punch" |
| `body_kick.fbx` | "roundhouse kick" / "mma kick" |
| `low_kick.fbx` | "low kick" / "leg kick" |
| `sweep.fbx` | "leg sweep" |
| `uppercut.fbx` | "uppercut" |
| `dash_punch.fbx` | "punching" / "lunge punch" |
| `rage_burst.fbx` | "combo punch" / "flying kick" |
| `throw.fbx` | "throw" / "grab" |

#### Mira's moves (`assets/characters/mira/anims/`)
| File name | Search Mixamo for |
|---|---|
| `tiger_claw.fbx` | "jab" / "quick punch" |
| `tiger_slash.fbx` | "hook punch" |
| `tiger_kick.fbx` | "side kick" |
| `to_crane.fbx` | "martial arts stance" / "kung fu stance" |
| `crane_peck.fbx` | "quick jab" |
| `crane_wing.fbx` | "elbow strike" / "palm strike" |
| `crane_rise.fbx` | "flip kick" / "rising kick" |
| `to_tiger.fbx` | "fighting stance" |
| `low_kick.fbx` | "low kick" |
| `sweep.fbx` | "leg sweep" |
| `throw.fbx` | "throw" / "grab" |

> You don't need everything at once. Any missing animation falls back to `idle`, and the tool tells you what's still missing.

## 2. Folder layout
```
assets/characters/
  kael/
    model.fbx
    anims/  idle.fbx  walk_forward.fbx  jab.fbx  …
  mira/
    model.fbx
    anims/  …
```

## 3. Build
```bash
godot --headless --path . --import                              # Godot converts the new FBX files
godot --headless --path . -s tools/build_animation_libraries.gd # builds animations.res, links the model
```
Example output:
```
kael: model res://assets/characters/kael/model.fbx
kael: 21 animations → res://data/characters/kael/animations.res
kael: all animations present ✓
```
The tool:
- makes `idle`, `walk_forward`, `walk_back` and `crouch` loop
- removes the hips' sideways movement ("root motion"), because the simulation decides where fighters stand
- sets `model_scene` and `animation_library` in the character's `character.tres`

## 4. Play
Run the game. Each attack animation is stretched to the move's exact frame data, so a jab animation always lasts exactly as long as the jab.

## Tuning tips
- **Wrong size:** `model_scale = 0` (the default) fits the model to `stand_height`. Set a number to override it.
- **An animation looks too fast or slow for its move:** trim it in Mixamo (the "Trim" slider) or pick a different one. The frame data stays the authority.
- **Facing the wrong way:** the view turns models 90° to face along the fight line, assuming they face +Z (Mixamo's default).
- **Your own (non-Mixamo) model:** in Godot's import dock, set Skeleton3D → Retarget → Bone Map to `SkeletonProfileHumanoid` for the model and every animation. Mixamo animations then play on it too.
