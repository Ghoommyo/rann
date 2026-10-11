# Guide — Making Your Own 3D Fighters (Tulbul Pandey & Bogembo)

From a picture to a rigged, animated fighter in the game, with **no 3D modelling skills**. Pipeline:

```
reference photo ─► original concept art ─► AI image-to-3D ─► Mixamo auto-rig ─► Mixamo animations ─► build tool
   (costume)         (ChatGPT / Gemini)     (Tripo / Meshy)     (free)             (free)            (already in repo)
```

Rigging on Mixamo gives your model the **same skeleton as Kael and Mira**, so every Mixamo animation plays on it, and `tools/build_animation_libraries.gd` works with no changes.

The game data already exists (`data/characters/tulbul_pandey`, `data/characters/bogembo`). Until a model is added, the fighter shows as a capsule, which is fully playable.

---

## ⚠️ Step 0 — Faces must be original

The photos of Salman Khan (Chulbul Pandey) and Amrish Puri (Mogambo) are for **costume and attitude only**. Don't feed them straight into image-to-3D. That copies a real person's face, and Indian courts actively enforce personality rights, which can get the game pulled from the stores. Parody names and homage moves are fine. Also, ship no real movie dialogue audio.

The photos live in `assets/characters/<id>/reference/`. That folder is gitignored (never committed) and has a `.gdignore`, so Godot doesn't import it.

---

## Step 1 — Concept art turnaround (ChatGPT / Gemini image generation)

Attach the reference photo and use the prompt below. Regenerate until the face reads as a **new person** and the pose is a clean T-pose. Then generate a **front**, **side** and **back** view; image-to-3D gets much better with 3 views.

**Tulbul Pandey**
> Original video-game fighter character, NOT the person in the photo — use the photo only for the costume. Realistic Tekken 8 style, full body, standing in a T-pose, arms straight out, feet slightly apart, neutral lighting, plain white background, front view. A broad-shouldered Indian police inspector in his 40s with a thick moustache and short slicked-back hair. Khaki police uniform with rolled sleeves, shoulder stars, a blue lanyard, medal ribbons, a thick leather belt with a big brass buckle, and gold aviator sunglasses worn on his face. Confident smirk.

**Bogembo**
> Original video-game villain, NOT the person in the photo — use the photo only for the costume. Realistic Tekken 8 style, full body, standing in a T-pose, arms straight out, feet slightly apart, neutral lighting, plain white background, front view. A tall, imposing Indian supervillain in his 60s with wild swept-back greying curly hair and very thick dark eyebrows, menacing glare. Black military coat covered in heavy gold embroidery, gold-braid epaulettes, a high jewelled collar, a coat that ends at mid-thigh (no long robe), black trousers, black boots.

Then: *"Same character, same outfit, side view"* / *"…back view"*.

> 💡 **Keep clothing tight to the body.** Long robes, capes and loose sleeves stretch badly on an auto-rig. That's why Bogembo's coat stops at mid-thigh.

## Step 2 — Image to 3D

Use any one of these:

| Tool | Cost | Notes |
|---|---|---|
| **Tripo3D** (tripo3d.ai) | free credits | Best results for textured humans; multi-view upload |
| **Meshy** (meshy.ai) | free credits | Very similar; also has an "A-pose/T-pose" option |
| **Hunyuan3D 2.x** (Hugging Face Space) | free | Open source, slower, rougher textures |

Settings: **Multi-view** (front, side, back images), realistic style, **20k–40k triangles** (a mobile budget), 2K texture. Export **FBX** (or OBJ, which also works on Mixamo).

Check before moving on: the arms are separated from the body, the fingers aren't fused into a block (mittens are OK), and the face looks right from the front.

> 💡 Some of these tools also offer auto-rigging. **Don't use it.** Use Mixamo instead, so the skeleton matches the other fighters.

## Step 3 — Quick Blender cleanup (optional, recommended)

Blender is free (blender.org). Import the FBX, then:

1. Move the model so the **feet are at height 0** and it is centred.
2. Make it **face forward**: front view (numpad 1) shows the face.
3. Select it, then `Ctrl+A` → **All Transforms**.
4. Triangle count over 40k? Add a **Decimate** modifier (ratio about 0.5) and apply it.
5. File → External Data → **Pack Resources**.
6. Export FBX: "Selected Objects", Path Mode **Copy** with the embed-textures icon on.

## Step 4 — Rig on Mixamo (mixamo.com, free Adobe account)

1. **Upload Character** → choose your FBX/OBJ.
2. Place the markers: **chin, wrists, elbows, knees, groin**. Use Symmetry on, and Skeleton LOD **Standard (65)**.
3. Preview: play an animation and check the armpits and knees don't tear. If they do, redo the markers (the elbows and groin matter most).
4. **Download** with Format **FBX Binary**, Pose **T-pose**, With Skin.
5. Save it as `assets/characters/<id>/model.fbx`:
   - `assets/characters/tulbul_pandey/model.fbx`
   - `assets/characters/bogembo/model.fbx`

## Step 5 — Animations

With **your uploaded character selected** on Mixamo, find each animation and download it with: **FBX Binary, Without Skin, 30 fps, In Place** (if offered). Save it to `assets/characters/<id>/anims/` and **rename it to the exact file name** in the tables below. The file name is the animation name the game looks for.

**Shared animations (both fighters):** `idle`, `walk_forward`, `walk_back`, `crouch`, `jump`, `land`, `hit`, `block`, `juggle`, `knockdown`, `wakeup`, `thrown`. Use the same search terms as [07-guide-mixamo-import.md](07-guide-mixamo-import.md#shared-animations-both-characters-need-these).
- Tulbul: a cocky "fighting idle" or "boxing idle".
- Bogembo: try "standing idle" or "angry idle" for a boss feel, and a slow "walking" for walk_forward.

### Tulbul Pandey — `assets/characters/tulbul_pandey/anims/`
| File name | Move (command) | Search Mixamo for |
|---|---|---|
| `jab.fbx` | Quick Jab (LP) | "lead jab" |
| `thappad.fbx` | Thappad (RP) | "slap" / "backhand" |
| `police_boot.fbx` | Police Boot (RK) | "front kick" / "push kick" |
| `lathi_poke.fbx` | Lathi Poke (2+LK) | "low kick" / "crouching kick" |
| `sweep.fbx` | Sweep (2+RK) | "leg sweep" |
| `buckle_uppercut.fbx` | Belt-Buckle Uppercut (3+RP) | "uppercut" |
| `belt_whip.fbx` | Belt Whip (236+RP) | "whip" / "sword slash" / "great sword slash" |
| `chashma_flip.fbx` | Chashma Flip (214+LP) | "taunt" / "adjusting glasses" / "cocky" |
| `dabangg_slowmo.fbx` | Dabangg Slow-Mo (236+LP+RP) | "punch combo" / "flying kick" |
| `throw.fbx` | Cop Arrest (LP+LK) | "throw" / "grab" |

### Bogembo — `assets/characters/bogembo/anims/`
| File name | Move (command) | Search Mixamo for |
|---|---|---|
| `backhand.fbx` | Backhand (LP) | "backhand" / "slap" |
| `tyrant_fist.fbx` | Tyrant Fist (RP) | "heavy punch" / "cross punch" |
| `throne_kick.fbx` | Throne Kick (RK) | "push kick" / "front kick" |
| `shin_stomp.fbx` | Shin Stomp (2+LK) | "stomp" / "low kick" |
| `robe_sweep.fbx` | Robe Sweep (2+RK) | "leg sweep" |
| `overlord_uppercut.fbx` | Overlord Uppercut (3+RP) | "uppercut" |
| `henchman_charge.fbx` | Henchman Charge (hold back, then 6+RP) | "shoulder charge" / "lunge punch" |
| `tezaab_drop.fbx` | Tezaab Drop (4+LP+RP) | "body slam" / "throw" |
| `laser_sweep.fbx` | Laser Sweep (236+RK) | "casting spell" / "magic attack" / "sweep" |
| `khush_hua.fbx` | Khush Hua! (236+LP+RP) | "grab and throw" / "suplex" |
| `throw.fbx` | Throw (LP+LK) | "throw" |

> Missing animations fall back to `idle`, so add them a few at a time. The build tool lists what's still missing.

## Step 6 — Build and play

```bash
godot --headless --path . --import                              # convert the new FBX files
godot --headless --path . -s tools/build_animation_libraries.gd # link model + animations
```
Then pick the fighters in character select and check them in **Training mode**.

## Troubleshooting
| Problem | Fix |
|---|---|
| Model faces sideways or backwards | It must face +Z (Mixamo's default). Re-export from Blender facing front, then re-rig. |
| Too big or small | `model_scale = 0` (the default) fits the model to `stand_height` (Bogembo is 1850, so he's taller). Set a number in `character.tres` to override. |
| Arms or coat stretch weirdly | Make the clothing tighter in Step 1, or redo the Mixamo markers. |
| Textures missing (white model) | Pack the textures in Blender (Step 3.5) and export FBX with embedded textures. |
| A move looks too fast or slow | Use the Trim slider on Mixamo. The frame data in `moves/*.tres` always decides the timing. |

## Later: higher quality
AI meshes look good from the game's camera distance but have messy topology. For a true Tekken-level finish, hire a 3D artist (ArtStation, Fiverr) to retopologise and texture them. Hand them the concept art from Step 1. If the result is rigged with Mixamo (or the Godot Humanoid profile), nothing else in this guide changes.
