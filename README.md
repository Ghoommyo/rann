# Rann

A 2.5D fighting game built with Godot 4. Plans and architecture are in [`plans/`](plans/README.md).

## Run
```bash
godot --path .                        # play (starts at the main menu)
godot --path . --editor               # open in the Godot editor
```

## Controls
| | Move | LP | RP | LK | RK |
|---|---|---|---|---|---|
| P1 keyboard | WASD | U | I | J | K |
| P2 keyboard | Arrows | Num 4 | Num 5 | Num 1 | Num 2 |
| Gamepad | D-pad / left stick | □ / X | △ / Y | ✕ / A | ○ / B |

Hold **back** to block high/mid, **down-back** to block low.
`Esc` / Start pause · `F1` collision boxes · `F2` touch controls · `F3` frame-data panel · `F5` restart · `Enter` rematch.
Training: `F6` change dummy behaviour · `F7` record / stop (then the dummy plays it back).

## Characters
| | Style | Signature |
|---|---|---|
| **Kael** | Striker, Rage meter | Rage Burst `236+LP+RP` (full meter) |
| **Mira** | Tiger ↔ Crane stances (`LK+RK`), parry (tap forward just before a high/mid hits) | Rising Crane launcher (Crane `RK`) |

3D models: see [plans/07-guide-mixamo-import.md](plans/07-guide-mixamo-import.md). Until you add them, fighters are capsules.

## Test
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```
