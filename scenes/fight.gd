## Runs one match: steps the simulation at 60 Hz, feeds it inputs (players,
## CPU or training dummy) and tells the views to draw it.
##
## 💡 The split between the two loops:
##  - _physics_process runs exactly 60 times a second → simulation ticks
##  - _process runs once per screen refresh → drawing, camera, sounds
## Mode and characters come from the Game autoload (chosen in the menus).
extends Node3D

const Event := FightState.Event

var _defs: Array[CharacterDef] = []
var _state: FightState
var _prev_state: FightState  # state one tick ago, for smooth interpolation
var _views: Array[FighterView] = []
var _cpu: CpuOpponent
var _dummy: TrainingDummy
var _pending_events: Array[Dictionary] = []  # sim events not yet shown/heard

@onready var _camera: CameraRig = $Camera
@onready var _overlay: HitboxOverlay = $HitboxOverlay
@onready var _effects: FightEffects = $Effects
@onready var _sounds: FightSounds = $Sounds
@onready var _hud: FightHud = $UI/FightHud
@onready var _touch: TouchControls = $UI/TouchControls
@onready var _pause: PauseMenu = $UI/PauseMenu


func _ready() -> void:
	InputRouter.register_default_actions()
	_defs = [_character(Game.p1_id), _character(Game.p2_id)]

	match Game.mode:
		Game.Mode.VERSUS_CPU:
			_cpu = CpuOpponent.new(Game.cpu_level, Time.get_ticks_usec())
		Game.Mode.TRAINING:
			_dummy = TrainingDummy.new()
			_hud.debug_visible = true

	for i in 2:
		var view := FighterView.new()
		view.name = "P%dView" % (i + 1)
		add_child(view)
		var color := _defs[i].color
		if i == 1 and _defs[0].id == _defs[1].id:
			color = color.darkened(0.45)  # mirror match: tell them apart
		view.setup(_defs[i], color)
		_views.append(view)

	_overlay.visible = false
	_pause.restart_requested.connect(_new_match)
	_pause.dummy_mode_requested.connect(_cycle_dummy)
	_new_match()


func _character(id: String) -> CharacterDef:
	var def := CharacterRegistry.get_def(id)
	return def if def else CharacterRegistry.all()[0]


func _new_match() -> void:
	_state = FightState.create(_defs, Game.mode != Game.Mode.TRAINING, Game.mode == Game.Mode.TRAINING)
	_prev_state = _state.copy()
	_pending_events.clear()
	_camera.snap(_state)
	_update_dummy_text()


func _physics_process(_delta: float) -> void:
	if _pause.is_open():
		return
	_prev_state = _state.copy()

	# Touch controls play as P1, together with P1's keyboard/gamepad.
	var p1 := InputRouter.read(1) | _touch.get_bits()
	var p2 := 0
	match Game.mode:
		Game.Mode.VERSUS_CPU:
			p2 = _cpu.next_input(_state, _defs, 1)
		Game.Mode.LOCAL_VERSUS:
			p2 = InputRouter.read(2)
		Game.Mode.TRAINING:
			var both := _dummy.inputs(_state, _defs, p1)
			p1 = both[0]
			p2 = both[1]

	MatchSim.step(_state, _defs, p1, p2)
	_pending_events.append_array(_state.events)


func _process(delta: float) -> void:
	var alpha := Engine.get_physics_interpolation_fraction()
	for i in 2:
		_views[i].show_state(_prev_state.fighters[i], _state.fighters[i], alpha, _state.frame)
	_camera.follow(_state, delta)
	_overlay.draw_state(_state, _defs)
	_hud.show_state(_state, _defs, delta, _debug_lines())

	for event in _pending_events:
		_effects.play(event)
		_sounds.play(event)
		match event.type:
			Event.HIT:
				_camera.shake(clampf(event.amount / 150.0, 0.2, 1.0))
			Event.KO:
				_camera.shake(1.4)
	_pending_events.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed \
			and event.button_index == JOY_BUTTON_START):
		if _pause.is_open():
			_pause.close()
		else:
			_pause.open()
		get_viewport().set_input_as_handled()
		return

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F1:
			_overlay.visible = not _overlay.visible
		KEY_F2:
			_touch.visible = not _touch.visible
		KEY_F3:
			_hud.debug_visible = not _hud.debug_visible
		KEY_F5:
			_new_match()
		KEY_F6:
			_cycle_dummy()
		KEY_F7:
			if _dummy:
				_dummy.toggle_recording()
				_update_dummy_text()
		KEY_ENTER, KEY_KP_ENTER:
			if _state.phase == FightState.Phase.MATCH_OVER:
				_new_match()


func _cycle_dummy() -> void:
	if _dummy:
		_dummy.next_mode()
		_update_dummy_text()


func _update_dummy_text() -> void:
	if _dummy:
		_pause.set_dummy_text("Dummy: %s" % TrainingDummy.MODE_NAMES[_dummy.mode])


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
	if _dummy:
		lines.append(_dummy.status())
	if _state.phase == FightState.Phase.MATCH_OVER:
		lines.append("[Enter] rematch   [Esc] menu")
	lines.append("F1 boxes  F2 touch  F3 this panel  F5 restart  Esc pause")
	return lines
