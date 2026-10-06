## Everything that makes one fighter different from another, stored as data.
##
## 💡 One .tres file per character lives in data/characters/<id>/character.tres.
## Adding a character means making a new file, not new code
## (plans/00-architecture.md, Rule 4). Edit the numbers in the Godot inspector.
##
## Phase 1 only has movement and body sizes. Moves (Phase 2) and the fight
## style (Phase 3) get added here later.
##
## All distances are in sim units (1000 = 1 meter); speeds are units per frame.
class_name CharacterDef
extends Resource

## Unique, never-changing id. Online play and replays refer to characters by this.
@export var id := ""
@export var display_name := ""
@export var max_health := 1000

@export_group("Walking")
## 40 units/frame × 60 frames = 2.4 m per second.
@export var walk_forward_speed := 40
## Walking back is usually slower than forward, which rewards being aggressive.
@export var walk_back_speed := 30

@export_group("Jumping")
## Frames on the ground before leaving it. The fighter is committed during them.
@export var jump_squat_frames := 4
## Upward speed on the first airborne frame.
@export var jump_velocity := 120
## Subtracted from vertical speed every frame. 120 / 8 → 15 frames up, 15 down.
@export var gravity := 8
## Horizontal speed for diagonal jumps (7 or 9).
@export var jump_forward_speed := 35
## Frames of landing recovery before the fighter can act again.
@export var landing_frames := 3

@export_group("Body")
## Half the width of the pushbox (the box that stops fighters overlapping).
@export var pushbox_half_width := 300
@export var stand_height := 1700
@export var crouch_height := 1000
## Smaller box in the air (the legs tuck in). It still reaches the opponent's
## standing box at the jump's peak, so fighters can't jump over each other,
## like in Tekken.
@export var air_height := 1200
