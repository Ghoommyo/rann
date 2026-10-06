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

# Online
var _session: RollbackSession
var _bot: CpuOpponent  # --net-bot: the CPU plays the local side (for testing)
var _match_number := 0
var _local_rematch := false
var _remote_rematch := false
var _opponent_gone := false
var _result_printed := false

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
		Game.Mode.ONLINE:
			if Game.online == null:
				Game.go_to_main_menu.call_deferred()
				return
			if Game.cli.bot:
				_bot = CpuOpponent.new(CpuOpponent.Level.HARD, 100 + (0 if Game.online.is_host else 1))

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
	if Game.mode == Game.Mode.ONLINE:
		var local := 0 if Game.online.is_host else 1
		_session = RollbackSession.new(_defs, local, Game.online.input_delay, Game.online.transport,
			FightState.create(_defs, true), _match_number)
		_state = _session.state
		_prev_state = _state.copy()
		_pending_events.clear()
		_hud.notice = ""
		_camera.snap(_state)
		return
	_state = FightState.create(_defs, Game.mode != Game.Mode.TRAINING, Game.mode == Game.Mode.TRAINING)
	_prev_state = _state.copy()
	_pending_events.clear()
	_camera.snap(_state)
	_update_dummy_text()


func _physics_process(_delta: float) -> void:
	if _pause.is_paused():
		return
	if Game.mode == Game.Mode.ONLINE:
		_online_tick()
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


## One online frame: the rollback session decides what to simulate.
func _online_tick() -> void:
	if _opponent_gone or _session == null:
		return
	_prev_state = _session.state.copy()
	var local := InputRouter.read(1) | _touch.get_bits()  # you always use the P1 controls
	if _bot:
		local = _bot.next_input(_session.state, _defs, _session.local_player)
	_session.tick(local)
	_state = _session.state
	_pending_events.append_array(_session.take_events())

	for msg in _session.other_messages:
		match msg[0]:
			NetMessages.Type.REMATCH:
				_remote_rematch = true
			NetMessages.Type.BYE:
				_on_opponent_left("Your opponent left the match.")
	_session.other_messages.clear()
	if not Game.online.transport.is_open() or _session.is_timed_out():
		_on_opponent_left("Connection to your opponent was lost.")
	if _session.desync_frame >= 0:
		_hud.notice = "Desync at frame %d: the games disagree (report saved)" % _session.desync_frame

	if _local_rematch and _remote_rematch:
		_local_rematch = false
		_remote_rematch = false
		_match_number += 1
		_new_match()
	elif _bot and _state.phase == FightState.Phase.MATCH_OVER and not _local_rematch:
		_request_rematch()
	_report_cli_result()


func _request_rematch() -> void:
	_local_rematch = true
	_session.send_message(NetMessages.Type.REMATCH)
	_hud.notice = "Waiting for your opponent to accept the rematch…"


func _on_opponent_left(text: String) -> void:
	if _opponent_gone:
		return
	_opponent_gone = true
	_hud.notice = text + " Returning to the menu…"
	_report_cli_result()
	get_tree().create_timer(4.0).timeout.connect(Game.go_to_main_menu)


## --net-frames=N: print the agreed checksum at frame N and quit (soak tests).
func _report_cli_result() -> void:
	if Game.cli.frames <= 0 or _result_printed:
		return
	var frame := ceili(Game.cli.frames / 60.0) * 60
	var checksum := _session.confirmed_checksum(frame)
	if checksum == -1 and not _opponent_gone:
		return
	_result_printed = true
	print("NET_RESULT player=%d frame=%d checksum=%d desync=%d rollbacks=%d max_rollback=%d stalls=%d ping=%d" % [
		_session.local_player + 1, frame, checksum, _session.desync_frame, _session.total_rollbacks,
		_session.max_rollback_frames, _session.stalls, _session.ping_ms])
	# Keep running a moment so the other side gets our last inputs.
	get_tree().create_timer(3.0).timeout.connect(get_tree().quit)


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
			if Game.mode != Game.Mode.ONLINE:
				_new_match()
		KEY_F6:
			_cycle_dummy()
		KEY_F7:
			if _dummy:
				_dummy.toggle_recording()
				_update_dummy_text()
		KEY_ENTER, KEY_KP_ENTER:
			if _state.phase == FightState.Phase.MATCH_OVER:
				if Game.mode == Game.Mode.ONLINE:
					if not _local_rematch:
						_request_rematch()
				else:
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
	if _session:
		lines.append("online: P%d  ping %d ms  delay %d  rollback %d (max %d)  stalls %d  desync %s" % [
			_session.local_player + 1, _session.ping_ms, _session.input_delay, _session.last_rollback_frames,
			_session.max_rollback_frames, _session.stalls,
			"none" if _session.desync_frame < 0 else "at frame %d" % _session.desync_frame])
	if _state.phase == FightState.Phase.MATCH_OVER:
		lines.append("[Enter] rematch   [Esc] menu")
	lines.append("F1 boxes  F2 touch  F3 this panel  F5 restart  Esc pause")
	return lines
