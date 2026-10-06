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
@onready var _debug_label: Label = $DebugHUD/Info


func _ready() -> void:
	InputRouter.register_default_actions()
	_defs = [p1_character, p2_character]
	_state = FightState.create(_defs)
	_prev_state = _state.copy()

	for i in 2:
		var view := FighterView.new()
		view.name = "P%dView" % (i + 1)
		add_child(view)
		view.setup(_defs[i], P1_COLOR if i == 0 else P2_COLOR)
		_views.append(view)
	_overlay.visible = false


func _physics_process(_delta: float) -> void:
	_prev_state = _state.copy()
	MatchSim.step(_state, _defs, InputRouter.read(1), InputRouter.read(2))


func _process(_delta: float) -> void:
	var alpha := Engine.get_physics_interpolation_fraction()
	for i in 2:
		_views[i].show_state(_prev_state.fighters[i], _state.fighters[i], alpha)
	_overlay.draw_state(_state, _defs)
	_update_debug_text()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		_overlay.visible = not _overlay.visible


func _update_debug_text() -> void:
	var lines := ["frame %d   checksum %08x   [F1] boxes" % [_state.frame, _state.checksum()]]
	for i in 2:
		var f := _state.fighters[i]
		lines.append("P%d  %-12s f%-3d  x %6d  y %5d  facing %+d" % [
			i + 1, FighterState.State.keys()[f.state], f.state_frame, f.pos_x, f.pos_y, f.facing])
	lines.append("P1: WASD    P2: arrow keys")
	_debug_label.text = "\n".join(lines)
