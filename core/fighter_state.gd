## The complete live state of one fighter: position, speed, current state, etc.
##
## 💡 Rules for this class (needed for rollback netcode in Phase 4):
##  - ints and bools only (plus the int-only style_data dictionary)
##  - every field must be copied in copy() and hashed in mix_checksum()
## If a field is added and forgotten in either place, online games will desync.
class_name FighterState
extends RefCounted

## The fighter's state machine. A fighter is always in exactly one of these.
## 💡 Each state decides which inputs it listens to and what comes next.
enum State {
	IDLE,
	WALK_FORWARD,
	WALK_BACK,
	CROUCH,
	JUMP_SQUAT,  # wind-up before leaving the ground
	AIRBORNE,
	LANDING,     # short recovery after touching down
	ATTACK,      # doing moves[move_index]
	HITSTUN,     # got hit, can't act for stun_frames
	BLOCKSTUN,   # blocked, can't act for stun_frames
	JUGGLE,      # launched into the air, can be hit again until landing
	KNOCKDOWN,   # lying on the floor
	WAKEUP,      # getting back up
	THROWING,    # holding the opponent in a throw
	THROWN,      # caught in a throw (can try to break it)
}

var character_id := ""

var pos_x := 0  # center of the feet, sim units
var pos_y := 0  # 0 = on the ground
var vel_x := 0
var vel_y := 0
var facing := 1  # +1 = facing right, -1 = facing left

var state := State.IDLE
var state_frame := 0  # how many frames the fighter has been in `state`
var jump_dir := 0  # -1 back, 0 straight up, +1 forward (relative to facing)

var health := 0

## Index into CharacterDef.moves of the current (or last) move, -1 = none.
var move_index := -1
## True once the current move has hit, been blocked or grabbed. A move only
## connects once, and connecting is what allows cancels.
var move_connected := false
## How long the current HITSTUN / BLOCKSTUN lasts.
var stun_frames := 0
## Blocking low (crouching) during BLOCKSTUN.
var crouch_guard := false
## Hits taken in the current combo. Drives damage and gravity scaling.
var combo_hits := 0
## Buffer timestamp of the button press that started the last move, so the
## same press can't start a second move.
var last_press_time := -1

var input := InputBuffer.new()

## Per-fighter data owned by fight-style components (Phase 3). Ints only.
var style_data := {}


## Switches state and restarts the state's frame counter.
func set_state(new_state: State) -> void:
	state = new_state
	state_frame = 0


## Like set_state(), but keeps the frame counter when already in that state
## (e.g. walking forward for several frames in a row).
func enter_state(new_state: State) -> void:
	if state != new_state:
		set_state(new_state)


func is_airborne() -> bool:
	return state == State.AIRBORNE or state == State.JUGGLE


func copy() -> FighterState:
	var c := FighterState.new()
	c.character_id = character_id
	c.pos_x = pos_x
	c.pos_y = pos_y
	c.vel_x = vel_x
	c.vel_y = vel_y
	c.facing = facing
	c.state = state
	c.state_frame = state_frame
	c.jump_dir = jump_dir
	c.health = health
	c.move_index = move_index
	c.move_connected = move_connected
	c.stun_frames = stun_frames
	c.crouch_guard = crouch_guard
	c.combo_hits = combo_hits
	c.last_press_time = last_press_time
	c.input = input.copy()
	c.style_data = style_data.duplicate(true)
	return c


func mix_checksum(h: int) -> int:
	h = FixedMath.hash_mix(h, character_id.hash())
	for value in [pos_x, pos_y, vel_x, vel_y, facing, state, state_frame, jump_dir, health,
			move_index, int(move_connected), stun_frames, int(crouch_guard), combo_hits,
			last_press_time]:
		h = FixedMath.hash_mix(h, value)
	h = input.mix_checksum(h)
	# Sorted keys so the hash doesn't depend on insertion order.
	var keys := style_data.keys()
	keys.sort()
	for key in keys:
		h = FixedMath.hash_mix(h, str(key).hash())
		h = FixedMath.hash_mix(h, style_data[key])
	return h
