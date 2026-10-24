# Guide: Recording your own moves (video → animation)

You act out each move in front of a phone camera. An AI motion-capture website turns the video into an animation on the fighter's own skeleton, and the game's build tool brings it in. No 3D animation skills needed.

The move list and what to act out for each clip: [10-tulbul-bogembo-moveset.md](10-tulbul-bogembo-moveset.md).

**Start with one clip** (Tulbul's `thappad`) and take it all the way into the game before recording the rest. That checks every step on a single move.

---

## 1. Filming
**Set-up**
- Phone in **landscape**, on a tripod or a shelf at **waist height**, not moving. 30 or 60 fps; normal video mode, not slow-mo.
- Stand **3–4 m** from the camera. Your **whole body, head to feet**, must stay in the frame the entire time, including kicks and arm swings. Mark your spot on the floor with tape.
- Face the camera at about a **45° angle**: your front shoulder towards the camera, your chest half-turned to it.
  - Fully side-on hides your far arm and leg, and the AI guesses them badly.
  - The build tool turns the fighter to face the right way afterwards.
  - Your **imagined opponent** stands in front of you, in the direction you punch and kick from your stance. Start every clip in that stance: the build tool turns each clip so the stance faces the opponent in the game.
- Plain wall behind you, bright even light, nobody else in the shot.
- Clothes that show your shape: fitted t-shirt and track pants. No long coats or loose kurtas: the AI can't see the body under them.
- Shoes on (or barefoot), the same for all clips.

**Each clip**
1. Stand in the fighter's **stance**, still, for about **1 second**.
2. Do the move **once**, big and clear. Exaggerate: games look better with bigger motions than real life.
3. Return to the **same stance**, and hold still for about **1 second**.
4. Stop recording. **One move per clip**, 3–6 seconds long.

The build tool cuts off the still parts at the start and end, and the game sets the move's speed itself, so you don't need to be fast or exactly on time.

**Name each video** after the `File` column of the move card, e.g. `thappad.mp4` → becomes `thappad.fbx`.

**Looping moves** (`idle`, `swag_idle`, `walk_forward`, `walk_back`, `crouch`): record 4–6 s of the motion, and try to end in the same pose you started in.

**Tips for each fighter**
- **Tulbul:** relaxed and cocky. Small lazy movements that snap fast on the hit. For `lathi_poke`, hold a broom. For `belt_whip`, really pull a belt.
- **Bogembo:** slow and grand. Wide shoulders, chin up, a little pose at the end of each move.
- For grabs (`cop_arrest`, `tezaab_drop`, `khush_hua`, `throw`), mime it with nobody there. Hold your hands at the height of a person's collar.

**Don't** act out getting hit or falling (`hit`, `juggle`, `knockdown`, `wakeup`, `thrown`). Keep the Mixamo versions of those.

---

## 2. Video → animation with DeepMotion

[DeepMotion Animate 3D](https://www.deepmotion.com/animate-3d) works in the browser. Its free plan gives a limited number of seconds per month, so check the current limits on its pricing page first. Trim your videos to just the move before uploading, so you don't waste seconds.

**Once per fighter: upload the character**
1. Make a free account and open **Animate 3D**.
2. Go to **Custom Characters** (or "Create / upload character") and upload the fighter's model:
   - `assets/characters/tulbul_pandey/model.fbx`
   - `assets/characters/bogembo/model.fbx`

   These are already rigged by Mixamo, and DeepMotion accepts Mixamo-rigged FBX files.
3. Check the preview: the character should stand in a T-pose, the right way up.

**For each video**
1. **New animation** → upload the video.
2. Settings:
   - **Character:** the fighter you uploaded, so the animation comes out on his own skeleton.
   - **Foot locking:** Auto.
   - **Physics filter / Smoothing:** on, at a low–medium amount. Too much smoothing makes punches soft.
   - **Root joint at origin / "in place":** if offered, turn it on. The game also does this itself.
3. Create, then watch the result.
   - If the arms or legs wobble or swap, re-film with better light, a plainer background, or more of your body in view.
4. **Download → FBX**, **30 fps**.
   - Save it in `assets/characters/<fighter id>/recorded/` with the move's file name, e.g. `assets/characters/tulbul_pandey/recorded/thappad.fbx`. Create the `recorded` folder the first time.
   - A clip in `recorded/` replaces the borrowed one in `anims/` with the same name. Leave `anims/` as it is: it's the fallback for moves you haven't recorded yet.

**Other tools that also work** (when DeepMotion's results or limits don't suit you):
- **Rokoko Video** (free, web).
- **Move.ai** (iPhone app).

These give you an animation on their own skeleton. It then has to be moved onto the fighter's skeleton in Blender (free) with the Rokoko Blender add-on: load the fighter, load the animation, use **Retarget** with the Mixamo bone list, and export the FBX without the mesh. Ask Claude to walk you through it if you go this way.

---

## 3. Into the game

When you've added one or more clips, say **"I added new moves"** to Claude, or run this yourself:
```bash
godot --headless --path . --import                              # read the new FBX files
godot --headless --path . -s tools/build_animation_libraries.gd # build them into the fighter
```
The build tool:
- turns each recorded clip to face forward,
- cuts the still lead-in and tail,
- locks the fighter in place, so it doesn't slide away.

It then prints a report of every move: **recorded**, **still Kael's** (an old copy that hasn't been replaced yet) or **missing**.

Check the move in **Training** mode:
- Press **F1** to show hitboxes. The strike in the animation should line up with when the red box appears.
- Play it from both sides.

---

## Troubleshooting
| Problem | Fix |
|---|---|
| Fighter is twisted or faces the wrong way | Make sure the clip starts with 1 s standing in your fighting stance, facing your imagined opponent. The tool uses the first frame to decide "forward". |
| Feet slide or float | Turn on foot locking in DeepMotion, and stand on a non-slippery floor. Small floating is fixed in the game automatically. |
| Arms pass through the body | Normal for AI capture. Exaggerate the move more, and keep the camera further away so nothing leaves the frame. |
| Hit happens before or after the strike in the animation | Tell Claude which move: the frame data can be nudged so the hit lines up with your strike. |
| The move feels slow or floaty | The game decides the speed from the move card's speed. Ask to make it faster; no need to re-record. |
| "No animation found" in the report | The FBX was exported without an animation. Download it again as FBX with animation (no "mesh only"). |
