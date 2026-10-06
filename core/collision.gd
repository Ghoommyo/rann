## Box collision for the simulation, using Rect2i (integer rectangles).
##
## 💡 Fighting games don't use realistic physics. Each fighter has a few
## invisible boxes:
##  - pushbox: stops fighters walking through each other (Phase 1)
##  - hurtbox: where the fighter can be hit
##  - hitbox:  the damaging part of an attack (defined in MoveDef)
##
## Boxes are in sim units. x grows to the right, y grows upwards, and
## Rect2i.position is the bottom-left corner.
class_name Collision


## True when the fighter is low to the ground: crouching, crouch-blocking,
## doing a low-profile move, or lying down. High attacks whiff over them.
static func is_low_posture(f: FighterState, def: CharacterDef) -> bool:
	match f.state:
		FighterState.State.CROUCH, FighterState.State.KNOCKDOWN, FighterState.State.WAKEUP:
			return true
		FighterState.State.BLOCKSTUN:
			return f.crouch_guard
		FighterState.State.ATTACK:
			return def.moves[f.move_index].low_profile
	return false


## Body height for the current posture.
static func body_height(f: FighterState, def: CharacterDef) -> int:
	if f.is_airborne():
		return def.air_height
	if is_low_posture(f, def):
		return def.crouch_height
	return def.stand_height


## The fighter's pushbox for its current state (shorter when crouching or jumping).
static func pushbox_of(f: FighterState, def: CharacterDef) -> Rect2i:
	var half := def.pushbox_half_width
	return Rect2i(f.pos_x - half, f.pos_y, half * 2, body_height(f, def))


## False while the fighter can't be hit at all (lying down, getting up, in a throw).
## 💡 Frames where a fighter can't be hit are called "invincibility frames".
static func has_hurtbox(f: FighterState) -> bool:
	match f.state:
		FighterState.State.KNOCKDOWN, FighterState.State.WAKEUP, \
		FighterState.State.THROWING, FighterState.State.THROWN:
			return false
	return true


## Where the fighter can be hit. Only meaningful when has_hurtbox() is true.
static func hurtbox_of(f: FighterState, def: CharacterDef) -> Rect2i:
	var half := def.hurtbox_half_width
	return Rect2i(f.pos_x - half, f.pos_y, half * 2, body_height(f, def))


## How far two boxes overlap horizontally (0 if they don't touch).
static func overlap_x(a: Rect2i, b: Rect2i) -> int:
	if not a.intersects(b):
		return 0
	return mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x)


## Keeps the fighter's pushbox inside the stage walls.
## Returns true if the fighter is touching a wall.
static func clamp_to_stage(f: FighterState, def: CharacterDef, left: int, right: int) -> bool:
	var lo := left + def.pushbox_half_width
	var hi := right - def.pushbox_half_width
	var clamped := clampi(f.pos_x, lo, hi)
	var at_wall := clamped != f.pos_x or f.pos_x == lo or f.pos_x == hi
	f.pos_x = clamped
	return at_wall


## Keeps both fighters on the stage, then pushes them apart if their
## pushboxes overlap. Each fighter moves half of the overlap. If one is
## against a wall, the other one takes the whole push.
static func resolve_pushboxes(a: FighterState, a_def: CharacterDef,
		b: FighterState, b_def: CharacterDef, stage_left: int, stage_right: int) -> void:
	clamp_to_stage(a, a_def, stage_left, stage_right)
	clamp_to_stage(b, b_def, stage_left, stage_right)

	var overlap := overlap_x(pushbox_of(a, a_def), pushbox_of(b, b_def))
	if overlap <= 0:
		return

	# Which way to push `a`: away from `b`. If they're exactly on top of each
	# other, use facing so the result is still deterministic.
	var dir := signi(a.pos_x - b.pos_x)
	if dir == 0:
		dir = -a.facing

	var half := overlap / 2
	a.pos_x += dir * (overlap - half)
	b.pos_x -= dir * half

	var a_at_wall := clamp_to_stage(a, a_def, stage_left, stage_right)
	var b_at_wall := clamp_to_stage(b, b_def, stage_left, stage_right)

	# A wall stopped part of the push: move the other fighter the rest of the way.
	overlap = overlap_x(pushbox_of(a, a_def), pushbox_of(b, b_def))
	if overlap > 0:
		if a_at_wall:
			b.pos_x -= dir * overlap
		elif b_at_wall:
			a.pos_x += dir * overlap
