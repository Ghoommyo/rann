# Rann

A 2.5D fighting game built with Godot 4. Plans and architecture are in [`plans/`](plans/README.md).

## Run
```bash
godot --path . scenes/fight.tscn      # play (P1: WASD, P2: arrow keys, F1: collision boxes)
godot --path . --editor               # open in the Godot editor
```

## Test
```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd
```
