# Rann

A 2.5D fighting game built with Godot 4. Plans and architecture are in [`plans/`](plans/README.md).

## Run
```bash
godot --path . scenes/fight.tscn      # play
godot --path . --editor               # open in the Godot editor
```

## Controls
| | Move | LP | RP | LK | RK |
|---|---|---|---|---|---|
| P1 keyboard | WASD | U | I | J | K |
| P2 keyboard | Arrows | Num 4 | Num 5 | Num 1 | Num 2 |
| Gamepad | D-pad / left stick | □ / X | △ / Y | ✕ / A | ○ / B |

Hold **back** to block high/mid, **down-back** to block low. `F1` collision boxes · `F2` touch controls · `F5` restart · `Enter` rematch.

## Test
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```
