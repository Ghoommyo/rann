# Tulbul Pandey & Bogembo: move cards

This is the design for both fighters' own styles. **Edit anything**: names, buttons, what a move does, how it should look. Then tell Claude, and the game data gets updated from this page.

Each card has a **"Act it out"** line. That's what you perform on camera for the move (see [11-guide-recording-moves.md](11-guide-recording-moves.md)). The clip file gets the name in the `File` column.

Words used below:
- **Poke:** a long, fairly safe hit that keeps the opponent away.
- **Launcher:** knocks them into the air for a follow-up combo.
- **Low:** must be blocked crouching.
- **Throw:** beats blocking.
- **Super:** costs a full meter.
- **Speed:** fast ≈ 9–11 frames before it hits, medium ≈ 12–16, slow ≈ 17+. The game sets the timing from these numbers, so your clip doesn't need exact timing; just do the move once, clearly.
- **Commands:** numbers are joystick directions as on a phone keypad, for a fighter facing right. 6 = forward, 4 = back, 2 = down, 3 = down-forward, 236 = quarter circle forward (down, down-forward, forward). `[4]6` = hold back, then forward.

---

## Tulbul Pandey: the swaggering cop
**Style:** a zoner who keeps you at belt's length with long pokes and the Belt Whip, parries your attacks (tap forward just before a hit lands), and builds SWAG.

His taunt, the **Chashma Flip**, puts him into **SWAG stance** for stronger finishers. Getting hit knocks him out of it.

**Personality on camera:** relaxed, chest out, one hand often near the belt. Small, lazy movements that suddenly snap fast.

### Basic moves (normal stance)
| File | Move | Command | What it does | Speed | Act it out |
|---|---|---|---|---|---|
| `jab.fbx` | Quick Jab | LP | Fast poke; chains into Thappad | fast | Short lead-hand jab, back to stance |
| `thappad.fbx` | Thappad | RP | His signature slap; chains into Belt Whip | medium | Big open-hand slap across, full follow-through, then a little shake of the hand |
| `shin_kick.fbx` | Shin Kick | LK | Quick mid kick | fast | Short snap kick at knee height with the front leg |
| `police_boot.fbx` | Police Boot | RK | Long front kick: a poke | medium | Big push kick straight forward with the boot sole |
| `lathi_poke.fbx` | Lathi Poke | 2+LK | Long low poke | medium | Crouch, jab a stick (use a broom) forward at ankle height |
| `sweep.fbx` | Sweep | 2+RK | Low that knocks down | slow | Crouch and sweep the back leg in a wide arc |
| `buckle_uppercut.fbx` | Belt-Buckle Uppercut | 3+RP | Launcher | medium | Dip, then a rising uppercut, finishing with the fist high |
| `belt_whip.fbx` | Belt Whip | 236+RP | Longest reach in his kit | slow | Pull the belt from your waist and whip it out in front, hand pulling back |
| `cop_arrest.fbx` | Cop Arrest | LP+LK | Throw | fast | Grab the collar with both hands, spin them round, push them down to the floor |

### SWAG stance
| File | Move | Command | What it does | Speed | Act it out |
|---|---|---|---|---|---|
| `chashma_flip.fbx` | Chashma Flip | 214+LP | Taunt → **enters SWAG stance** | medium | Take sunglasses off, flip them, and hook them into the back of your collar |
| `swag_idle.fbx` | (SWAG standing pose) | while in SWAG | His stance idle | — | Loop of 2–3 s: thumbs in belt, slight sway, head tilted (Chulbul's walk-in vibe) |
| `double_thappad.fbx` | Double Thappad | RP in SWAG | Two slaps, knocks down → back to normal | medium | Forehand slap, then backhand slap with the same hand |
| `chair_kick.fbx` | Kursi Kick | RK in SWAG | Launches, big damage → back to normal | slow | Wind up and kick an imaginary chair flying forward |
| `duty_reset.fbx` | Back on Duty | LK+RK in SWAG | Leave SWAG stance quickly | fast | Straighten the shirt collar, back to stance |

### Super
| File | Move | Command | What it does | Speed | Act it out |
|---|---|---|---|---|---|
| `dabangg_slowmo.fbx` | Dabangg Slow-Mo | 236+LP+RP | Super: rushing combo, knocks down | fast | Slow, swaggering two steps forward, then a sudden heavy punch–slap combo |

---

## Bogembo: the boss
**Style:** slow and heavy, with the most health and the biggest hits. He wants you close:
- Hold back to charge the **Henchman Charge**.
- Up close, his **Tezaab Drop** can't be broken.
- With a full KHUSH meter, **Khush Hua!** grabs you for huge damage.

**Personality on camera:** big, slow, theatrical. Shoulders wide, chin up, gestures like a king on a throne. Every move ends with a little "pose".

### Basic moves
| File | Move | Command | What it does | Speed | Act it out |
|---|---|---|---|---|---|
| `backhand.fbx` | Backhand | LP | His fastest hit; chains into Tyrant Fist | fast | Lazy backhand swat with the lead hand, like brushing someone aside |
| `tyrant_fist.fbx` | Tyrant Fist | RP | Heavy straight punch | medium | Big wind-up, heavy straight punch with the whole body behind it |
| `royal_shove.fbx` | Royal Shove | LK | Pushes the opponent far away | medium | Two-handed shove forward, then dust your hands off |
| `throne_kick.fbx` | Throne Kick | RK | Heavy mid kick | medium | Lean back as if seated on a throne and kick forward with the sole |
| `shin_stomp.fbx` | Shin Stomp | 2+LK | Low | medium | Raise a knee and stomp down hard in front of you |
| `robe_sweep.fbx` | Robe Sweep | 2+RK | Low that knocks down | slow | Crouch and swing a wide leg sweep, arms spread like a cape |
| `overlord_uppercut.fbx` | Overlord Uppercut | 3+RP | Launcher | medium | Scoop from low to high with an open palm, ending with an arm raised in triumph |
| `henchman_charge.fbx` | Henchman Charge | [4]6+RP | Charge rush across the screen | medium | Lean back, then lunge forward two steps with a shoulder barge |
| `laser_sweep.fbx` | Laser Sweep | 236+RK | Long low sweep ("ray gun") | slow | Point an arm and sweep it slowly from side to side, as if firing a ray |
| `throw.fbx` | Boss Toss | LP+LK | Throw | fast | Grab with one hand, swing them past you, let go |

### Grabs and super
| File | Move | Command | What it does | Speed | Act it out |
|---|---|---|---|---|---|
| `tezaab_drop.fbx` | Tezaab Drop | 4+LP+RP | **Unbreakable** throw | fast | Grab with both hands, lift high above your head, drop them forward into the "acid pit" |
| `khush_hua.fbx` | Khush Hua! | 236+LP+RP | Super grab, huge damage | fast | Grab, pull them close, then fling them away and throw your head back laughing with arms spread |

---

## Shared movements (both fighters)
| File | What it is | Record yourself? |
|---|---|---|
| `idle.fbx` | Standing fight pose (loops) | ✅ yes: this is most of their personality. 2–3 s loop, start and end in the same pose |
| `walk_forward.fbx`, `walk_back.fbx` | Walking (loops) | ✅ yes: Tulbul swaggers, Bogembo lumbers. 2–4 steps, side-on, end like you started |
| `crouch.fbx` | Crouching guard (loops) | ✅ yes |
| `block.fbx` | Guarding a hit | ✅ yes: arms up, flinch slightly backwards |
| `jump.fbx`, `land.fbx` | Jump and landing | ✅ yes, if you have room (or keep the current ones) |
| `hit.fbx`, `juggle.fbx`, `knockdown.fbx`, `wakeup.fbx`, `thrown.fbx` | Getting hit, falling, getting up | ❌ no: falling on the floor is unsafe to act out. Keep Mixamo clips ("Hit Reaction", "Falling Back Death", "Getting Up", "Flying Back Death") |
