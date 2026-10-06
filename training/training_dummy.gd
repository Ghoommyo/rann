## Controls P2 in training mode.
##
## 💡 Training mode is where players practice combos and learn frame data,
## and it's also the best tool for testing a new character. The dummy can:
##  - stand, crouch, jump, block everything, or fight back as a CPU
##  - record: P1's controls drive the dummy while recording; afterwards
##    PLAYBACK repeats that recording in a loop (to practice against a
##    specific attack or pressure string)
class_name TrainingDummy
extends RefCounted

enum Mode { STAND, CROUCH, BLOCK_ALL, JUMP, CPU, PLAYBACK }

const MODE_NAMES := ["Stand", "Crouch", "Block all", "Jump", "CPU (Hard)", "Playback"]

var mode := Mode.STAND
var recording := false
var _recorded: Array[int] = []
var _playback_index := 0
var _cpu := CpuOpponent.new(CpuOpponent.Level.HARD, 99)


func next_mode() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	_playback_index = 0


func toggle_recording() -> void:
	recording = not recording
	if recording:
		_recorded.clear()
	else:
		mode = Mode.PLAYBACK
		_playback_index = 0


func status() -> String:
	if recording:
		return "Dummy: RECORDING (%d frames) — you control P2  [F7 stop]" % _recorded.size()
	return "Dummy: %s   [F6 change, F7 record]" % MODE_NAMES[mode]


## Returns [p1_input, p2_input] for this frame.
func inputs(state: FightState, defs: Array[CharacterDef], p1_bits: int) -> Array[int]:
	if recording:
		_recorded.append(p1_bits)
		return [0, p1_bits]  # P1 stands still while the player drives the dummy
	var dummy := state.fighters[1]
	var p2 := 0
	match mode:
		Mode.CROUCH:
			p2 = InputFrame.DOWN
		Mode.JUMP:
			p2 = InputFrame.UP
		Mode.BLOCK_ALL:
			p2 = _perfect_guard(state.fighters[0], defs[0], dummy.facing)
		Mode.CPU:
			p2 = _cpu.next_input(state, defs, 1)
		Mode.PLAYBACK:
			if not _recorded.is_empty():
				p2 = _recorded[_playback_index]
				_playback_index = (_playback_index + 1) % _recorded.size()
	return [p1_bits, p2]


## Blocks every attack correctly (high/mid standing, low crouching).
func _perfect_guard(attacker: FighterState, attacker_def: CharacterDef, facing: int) -> int:
	var guard := 4
	if attacker.state == FighterState.State.ATTACK:
		var move := attacker_def.moves[attacker.move_index]
		if move.hit_level == MoveDef.HitLevel.LOW:
			guard = 1
	return InputFrame.from_numpad(guard, facing)
