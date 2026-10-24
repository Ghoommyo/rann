# Plan: Add Tulbul Pandey and Bogembo (custom 3D fighters)

## Context
Rann currently has Kael and Mira, both using Mixamo stock models. The user wants two new fighters of their own, built from their reference pictures in a realistic, Tekken 8 style:
- **Tulbul Pandey**: a parody of Chulbul Pandey (*Dabangg*). A swaggering cop, played as a zoner/counter fighter.
- **Bogembo**: a parody of Mogambo (*Mr. India*). A theatrical supervillain boss.

They will be new fighters alongside Kael and Mira. The user is new to game development, so most of the art work is a pipeline they run by hand; the code side is small.

**Reusable pieces already in the repo:**
- `tools/build_animation_libraries.gd` picks up `assets/characters/<id>/model.fbx|glb` plus `anims/*.fbx`, builds `animations.res`, strips root motion and links both into `character.tres`.
- `tools/gen_characters.py` generates CharacterDef, style and MoveDef `.tres` files from Python dicts.
- `core/style/parry_component.gd`, `meter_component.gd` and `charge_input_component.gd` already exist. There is **no projectile system**, so "ranged" moves become long, slow, disjointed hitboxes. No engine code is needed.
- `view/fighter_view.gd` `STATE_ANIMS` lists the 12 shared animation names every model needs.

**Reference photos (from the user):** Mogambo (Amrish Puri) is the base for Bogembo, and Chulbul Pandey (Salman Khan) is the base for Tulbul. Use them for **costume, silhouette and attitude only, not the face**:
- Tulbul: khaki police uniform with shoulder stars and a blue lanyard, medal ribbons, gold aviators, thick moustache, short slicked hair, chest-out swagger.
- Bogembo: black military coat with heavy gold embroidery and gold-braid epaulettes, a high jewelled collar, wild swept-back curly hair, thick dark brows, a menacing glare.

**Likeness rule:** do **not** feed the actor photos straight into image-to-3D. That reproduces real people's faces, and Indian courts actively enforce personality rights, including recent orders for Salman Khan. That risks store takedowns. Instead, first generate an *original* character in that costume (step 1 below), then make the 3D model from that. Parody names, homage moves and paraphrased text lines are fine; ship no real dialogue audio.

## Part A: Art pipeline (the user does this; I write it up as a guide)

**Image → 3D mesh → Mixamo auto-rig → Mixamo animations.** Mixamo's auto-rigger gives the model the same skeleton as Kael and Mira, so the existing tool works with no changes.

1. **Concept turnaround:** use an image model (ChatGPT/Gemini) with the photo as a *costume* reference: "original character, not this actor's face, realistic Tekken 8 style, full body T-pose, front/side/back views, white background, wearing <costume above>". Repeat until the face reads as a new person. The guide will include ready-made prompts for both characters.
2. **Image → 3D:** use **Tripo3D** or **Meshy** (multi-view input, realistic textured humans), or **Hunyuan3D 2.x** (free) as a fallback. Aim for about 20k–40k triangles and 2K textures, and export FBX or OBJ.
   - Tulbul: khaki police uniform, aviator sunglasses tucked into the back of the collar, a belt with a big buckle, a moustache.
   - Bogembo: tall and imposing, with swept-back curly hair, heavy brows, a black gold-embroidered military coat, epaulettes and a jewelled high collar.
3. **Blender cleanup (optional, about 30 minutes):** apply scale, face +Z, feet at Y=0, decimate if over 40k triangles, pack the textures.
4. **Mixamo rig:** Upload Character → place the markers → download as *FBX Binary, T-pose* to `assets/characters/<id>/model.fbx`.
   - Bogembo's long robe will stretch with the leg bones. Choose shorter or split coat tails in the image prompt.
5. **Animations:** download each one as *FBX Binary, Without Skin, 30 fps, In Place*, named per the guide's tables, into `assets/characters/<id>/anims/`.
6. **Build:** `godot --headless --path . --import`, then `godot --headless --path . -s tools/build_animation_libraries.gd`.

AI meshes are fine for a mobile 2.5D camera. A Tekken-level finish would need a 3D artist, as a later polish pass.

## Part B: Movesets (I implement these as data)

### Tulbul Pandey: `tulbul_pandey`, zoner/counter
Style: `parry` (window about 6f, called "Dabangg Reflex") plus a `meter` called **SWAG** (gains on parry and on hit). Health 1000, average walk speed, long reach.

| Cmd | Move | Homage | Notes |
|---|---|---|---|
| LP | Quick Jab | | 10f, the jab every character needs |
| RP | Thappad (slap) | the famous slap line | 13f, high, long-ish reach, +on hit |
| RK | Police Boot | the boot kick that sends goons flying | 15f mid, about 800 hitbox width, safe poke |
| 2+LK | Lathi Sweep-poke | | low poke, long reach |
| 2+RK | Sweep | | knockdown |
| 3+RP | Belt-Buckle Uppercut | | launcher, unsafe |
| 236+RP | Belt Whip | belt-as-whip fights | long, slow, disjointed mid (about 1000 width), safe on block: his zoning tool |
| 214+LP | Chashma Flip | sunglasses flick to the back collar | short taunt; builds SWAG; recovery can be cancelled into Belt Whip |
| 236+LP+RP | Dabangg Slow-Mo | slow-motion beat-down | super, 1000 SWAG; long hitstop, knockdown |
| LP+LK | Cop Arrest | | throw |

### Bogembo: `bogembo`, boss/grappler
Style: `charge_input` (hold back, then forward) plus a `meter` called **KHUSH** ("Bogembo khush hua"). It gains on hit and on blocked moves taken, and fills faster as he lands grabs. Health 1150, slow walk, big hurtbox.

| Cmd | Move | Homage | Notes |
|---|---|---|---|
| LP | Backhand | | 11f jab |
| RP | Tyrant Fist | | heavy, high damage, minus on block |
| RK | Throne Kick | | mid push kick |
| 2+LK | Shin Stomp | | low |
| 2+RK | Robe Sweep | | knockdown |
| 3+RP | Overlord Uppercut | | launcher |
| [4]6+RP | Henchman Charge | "Mogambo's army" | charge rush, armour-feel via big pushback |
| 4+LP+RP (close) | Tezaab Drop | the acid-tank execution | command grab (throw level, cannot be broken), huge damage |
| 236+RK | Laser Sweep | the laser gadget | very slow, very long disjointed low hitbox |
| 236+LP+RP | Khush Hua! | | super, 1000 KHUSH, command-grab super |
| LP+LK | Throw | | standard throw |

Win lines (text only, paraphrased): Tulbul, "Darr nahi lagta… Swag lagta hai." Bogembo, "Bogembo khush hua!"

## Git workflow (user request)
- Create the branch `feature/tulbul-bogembo` from main and push it with `-u origin`.
- Commit and push at each major step: (1) plan doc, (2) generator + Tulbul data, (3) Bogembo data + roster updates + tests passing, (4) art guide.
- Update the memory file `git-commit-workflow.md`: feature work now goes on a feature branch, which gets pushed on major changes, not directly to main.
- The reference photos go in `assets/characters/<id>/reference/`, which gets a `.gdignore` (so Godot doesn't import them) and a `.gitignore` entry (so the actor photos aren't committed).

## Files
- `plans/08-tulbul-bogembo.md`: a copy of this plan, which is the first commit on the branch.
- `tools/gen_characters.py`: add `TULBUL` and `BOGEMBO` dicts, plus a CLI arg (`python3 tools/gen_characters.py tulbul_pandey bogembo`) so it generates **only** those ids and never overwrites the hand-tuned Kael and Mira files.
- Generated: `data/characters/{tulbul_pandey,bogembo}/character.tres`, `style.tres`, `moves/*.tres`.
- If the existing components can't express "unbreakable command grab", "meter gain on parry" or "close-range only", I'll use what the existing components and fields already support and say what was approximated, rather than inventing engine code.
- `plans/09-guide-custom-characters.md`: the Part A guide, the image prompts and the per-character animation tables (file name → Mixamo search terms, e.g. `belt_whip.fbx` → "whip"/"sword slash", `tezaab_drop.fbx` → "throw"/"body slam").
- `README.md`: add both to the Characters table and link the guide.
- Any places where the roster of two is hard-coded (character select, AI, tests): update them for four.

Until the models arrive, both fighters show as capsules (an existing fallback), so the code can be merged and played right away.

## Verification
- Run the tests headless (`tests/`, including `test_registry.gd` and `test_character_data.gd`); they should pass with 4 characters.
- Launch the game: Tulbul and Bogembo appear in select. In Training mode, check each move's frame data and hitbox overlay with capsules.
- After the user adds the art: the build tool should report all animations present, and in game the models should face correctly and be scaled to `stand_height`.
- Each milestone is committed and pushed to `feature/tulbul-bogembo`; the branch merges to main once the user is happy.
