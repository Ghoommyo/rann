## Runs one local match: steps the simulation at 60 Hz and tells the views
## to draw it.
##
## 💡 The split between the two loops:
##  - _physics_process runs exactly 60 times a second → simulation ticks
##  - _process runs once per screen refresh → drawing only
extends Node3D

@export var p1_character: CharacterDef
@export var p2_character: CharacterDef

const P1_COLOR := Color(0.2, 0.45, 0.95)
const P2_COLOR := Color(0.9, 0.25, 0.25)

var _defs: Array[CharacterDef] = []
var _state: FightState
var _prev_state: FightState  # state one tick ago, for smooth interpolation
var _views: Array[FighterView] = []

@onready var _overlay: HitboxOverlay = $HitboxOverlay
@onready var _hud: FightHud = $UI/FightHud
@onready var _touch: TouchControls = $UI/TouchControls


func _ready() -> void:
	InputRouter.register_default_actions()
	_defs = [p1_character, p2_character]
	_new_match()

	for i in 2:
		var view := FighterView.new()
		view.name = "P%dView" % (i + 1)
		add_child(view)
		view.setup(_defs[i], P1_COLOR if i == 0 else P2_COLOR)
		_views.append(view)
	_overlay.visible = false


func _new_match() -> void:
	_state = FightState.create(_defs, true)
	_prev_state = _state.copy()


func _physics_process(_delta: float) -> void:
	_prev_state = _state.copy()
	# Touch controls play as P1, together with P1's keyboard/gamepad.
	var p1_input := InputRouter.read(1) | _touch.get_bits()
	MatchSim.step(_state, _defs, p1_input, InputRouter.read(2))


func _process(_delta: float) -> void:
	var alpha := Engine.get_physics_interpolation_fraction()
	for i in 2:
		_views[i].show_state(_prev_state.fighters[i], _state.fighters[i], alpha)
	_overlay.draw_state(_state, _defs)
	_hud.show_state(_state, _defs, _debug_lines())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			_overlay.visible = not _overlay.visible
		KEY_F2:
			_touch.visible = not _touch.visible
		KEY_ENTER, KEY_KP_ENTER:
			if _state.phase == FightState.Phase.MATCH_OVER:
				_new_match()
		KEY_F5:
			_new_match()


func _debug_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("frame %d   checksum %08x" % [_state.frame, _state.checksum()])
	for i in 2:
		var f := _state.fighters[i]
		var move := ""
		if f.state == FighterState.State.ATTACK or f.state == FighterState.State.THROWING:
			move = _defs[i].moves[f.move_index].display_name
		lines.append("P%d  %-10s f%-3d %-14s hp %4d  combo %d" % [
			i + 1, FighterState.State.keys()[f.state], f.state_frame, move, f.health, f.combo_hits])
	if _state.last_attacker >= 0:
		var move_name := _defs[_state.last_attacker].moves[_state.last_move_index].display_name
		var adv := "n/a" if _state.last_advantage == Rules.NO_ADVANTAGE else "%+d" % _state.last_advantage
		lines.append("last: P%d %s on %s  →  %s" % [
			_state.last_attacker + 1, move_name, "block" if _state.last_blocked else "hit", adv])
	lines.append("P1: WASD + U I J K    P2: arrows + numpad 4 5 1 2")
	lines.append("F1 boxes   F2 touch controls   F5 restart")
	return lines
