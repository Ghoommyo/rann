## Runs one online match with rollback netcode.
##
## 💡 How it works (see plans/04-phase-online-multiplayer.md):
##  1. Every frame, each player sends only their INPUT (one int), never the state.
##  2. If the opponent's input for this frame hasn't arrived yet, PREDICT it
##     (assume they're still holding what they held last) and keep going.
##  3. Save a copy of the state every frame.
##  4. When the real input arrives and differs from the prediction, ROLL BACK:
##     load the saved state from that frame and re-simulate up to now with the
##     correct input. This all happens within one rendered frame.
## This only works because MatchSim.step() is deterministic and FightState
## can be copied (the rules from Phase 1).
##
## Input delay: local inputs are applied `input_delay` frames late. A couple of
## frames of delay hide most of the network lag, so rollbacks are smaller.
##
## The session is pure logic: it talks to the network through a NetTransport,
## so tests can run two sessions over a simulated network.
class_name RollbackSession
extends RefCounted

## Furthest the simulation may run ahead of the opponent's confirmed inputs.
## Beyond this, the session waits ("stalls") instead of predicting further.
const MAX_ROLLBACK := 8
## How many unacknowledged inputs to repeat in each packet (covers packet loss).
const MAX_INPUTS_PER_PACKET := 64
const CHECKSUM_INTERVAL := 60
const PING_INTERVAL := 30
## No packets for this long = the opponent is gone.
const TIMEOUT_MS := 10000

var state: FightState
var defs: Array[CharacterDef]
var local_player: int  # 0 = P1 (host), 1 = P2
var input_delay: int
## Counts rematches. Packets from an earlier match (still in flight when a
## rematch starts) carry an older number and are ignored.
var match_number: int

# --- Stats for the HUD ---
var ping_ms := 0
var last_rollback_frames := 0
var max_rollback_frames := 0
var total_rollbacks := 0
var stalls := 0
## First frame where the two games disagreed, or -1.
var desync_frame := -1

## How many frames of inputs to remember (tests raise it to replay whole matches).
var keep_input_frames := 600

## Messages the session doesn't handle itself (REMATCH, BYE, …), for fight.gd.
var other_messages: Array[Array] = []

var _transport: NetTransport
var _local_inputs := {}     # frame → bits (frame = the sim frame they're used on)
var _remote_inputs := {}    # frame → bits, confirmed by the opponent
var _predicted := {}        # frame → the remote bits we guessed for that frame
var _last_remote_frame := -1  # all remote inputs up to here are known
var _newest_local_frame := -1  # newest frame we have a local input for
var _remote_ack := -1       # the opponent has all our inputs up to here
var _saved := {}            # frame → FightState copy taken BEFORE simulating that frame
var _rollback_from := -1    # earliest frame with a wrong prediction
var _played_events := {}    # event keys already shown (see _collect_events)
var _new_events: Array[Dictionary] = []
var _local_checksums := {}  # frame → checksum of the state at the start of that frame
var _sent_checksums := {}
var _remote_checksums := {}
var _last_receive_ms := 0


func _init(fight_defs: Array[CharacterDef], player: int, delay: int, transport: NetTransport,
		start_state: FightState, match_no := 0) -> void:
	defs = fight_defs
	match_number = match_no
	local_player = player
	input_delay = delay
	_transport = transport
	state = start_state
	# The first `input_delay` frames have no input from either side: neutral.
	for f in input_delay:
		_local_inputs[f] = 0
		_remote_inputs[f] = 0
	_last_remote_frame = input_delay - 1
	_newest_local_frame = input_delay - 1
	_last_receive_ms = Time.get_ticks_msec()


## Advances the match by one frame (or waits). Call once per physics tick
## with this frame's local input. Returns false if it had to wait.
func tick(local_bits: int) -> bool:
	_receive()

	var target := state.frame + input_delay
	if not _local_inputs.has(target):
		_local_inputs[target] = local_bits
		_newest_local_frame = target

	# Too far ahead of the opponent: wait for their inputs to catch up.
	if state.frame - _last_remote_frame > MAX_ROLLBACK:
		stalls += 1
		_send_inputs()
		return false

	last_rollback_frames = 0
	if _rollback_from >= 0:
		_roll_back()

	_simulate(state.frame)
	_send_inputs()
	_send_checksums()
	if state.frame % PING_INTERVAL == 0:
		_transport.send(NetMessages.encode(NetMessages.Type.PING, [Time.get_ticks_msec()]), false)
	_prune()
	return true


## Events that should be shown/heard now (each one only once, even after rollbacks).
func take_events() -> Array[Dictionary]:
	var events := _new_events
	_new_events = []
	return events


## Both players' inputs for a frame whose inputs are all confirmed.
func confirmed_inputs(frame: int) -> Array[int]:
	var local: int = _local_inputs.get(frame, 0)
	var remote: int = _remote_inputs.get(frame, 0)
	var pair: Array[int] = [local, remote]
	if local_player == 1:
		pair = [remote, local]
	return pair


## The newest frame for which both players' inputs are known.
func confirmed_frame() -> int:
	return mini(_last_remote_frame, state.frame - 1)


## Checksum of the state at the start of `frame`, once it's final, else -1.
func confirmed_checksum(frame: int) -> int:
	if frame - 1 > _last_remote_frame or not _local_checksums.has(frame):
		return -1
	return _local_checksums[frame]


func is_timed_out() -> bool:
	return Time.get_ticks_msec() - _last_receive_ms > TIMEOUT_MS


func send_message(type: NetMessages.Type, payload: Array = []) -> void:
	_transport.send(NetMessages.encode(type, payload), true)


# --- Simulation ---

func _simulate(frame: int) -> void:
	_saved[frame] = state.copy()
	var remote: int
	if _remote_inputs.has(frame):
		remote = _remote_inputs[frame]
		_predicted.erase(frame)
	else:
		remote = _remote_inputs.get(_last_remote_frame, 0)  # prediction: same as last known
		_predicted[frame] = remote
	var local: int = _local_inputs.get(frame, 0)
	if local_player == 0:
		MatchSim.step(state, defs, local, remote)
	else:
		MatchSim.step(state, defs, remote, local)
	_collect_events(frame)
	if state.frame % CHECKSUM_INTERVAL == 0:
		_local_checksums[state.frame] = state.checksum()


func _roll_back() -> void:
	var now := state.frame
	var from := _rollback_from
	_rollback_from = -1
	state = _saved[from].copy()
	for f in range(from, now):
		_simulate(f)
	last_rollback_frames = now - from
	max_rollback_frames = maxi(max_rollback_frames, last_rollback_frames)
	total_rollbacks += 1


## Keeps events the player hasn't seen yet. After a rollback the same hit is
## simulated again; its key matches, so its spark and sound don't repeat.
func _collect_events(frame: int) -> void:
	for e in state.events:
		var key := "%d:%d:%d:%d" % [frame, e.type, e.fighter, e.amount]
		if not _played_events.has(key):
			_played_events[key] = frame
			_new_events.append(e)


# --- Network ---

func _receive() -> void:
	for bytes in _transport.poll():
		var msg := NetMessages.decode(bytes)
		if msg.is_empty():
			continue
		_last_receive_ms = Time.get_ticks_msec()
		match msg[0]:
			NetMessages.Type.INPUT:
				if msg[1] == match_number:
					_on_inputs(msg[2], msg[3], msg[4])
			NetMessages.Type.CHECKSUM:
				if msg[1] == match_number:
					_remote_checksums[msg[2]] = msg[3]
					_compare_checksum(msg[2])
			NetMessages.Type.PING:
				_transport.send(NetMessages.encode(NetMessages.Type.PONG, [msg[1]]), false)
			NetMessages.Type.PONG:
				ping_ms = Time.get_ticks_msec() - int(msg[1])
			_:
				other_messages.append(msg)


func _on_inputs(first_frame: int, bits: PackedInt32Array, ack: int) -> void:
	_remote_ack = maxi(_remote_ack, ack)
	for i in bits.size():
		var frame := first_frame + i
		if frame <= _last_remote_frame or _remote_inputs.has(frame):
			continue
		_remote_inputs[frame] = bits[i]
		# Already simulated this frame with a guess that turned out wrong?
		if _predicted.has(frame) and _predicted[frame] != bits[i]:
			_rollback_from = frame if _rollback_from < 0 else mini(_rollback_from, frame)
	while _remote_inputs.has(_last_remote_frame + 1):
		_last_remote_frame += 1


func _send_inputs() -> void:
	var first := maxi(_remote_ack + 1, input_delay)
	# Only send inputs that really exist: a frame sent as "0" would be taken
	# as the real input by the other side.
	var last := _newest_local_frame
	if first > last:
		return
	first = maxi(first, last - MAX_INPUTS_PER_PACKET + 1)
	var bits := PackedInt32Array()
	for f in range(first, last + 1):
		bits.append(_local_inputs.get(f, 0))
	_transport.send(NetMessages.encode(NetMessages.Type.INPUT,
		[match_number, first, bits, _last_remote_frame]), false)


func _send_checksums() -> void:
	for frame in _local_checksums:
		if _sent_checksums.has(frame) or frame - 1 > _last_remote_frame:
			continue  # not final yet: an input before it could still change
		_sent_checksums[frame] = true
		send_message(NetMessages.Type.CHECKSUM, [match_number, frame, _local_checksums[frame]])
		_compare_checksum(frame)


func _compare_checksum(frame: int) -> void:
	if desync_frame >= 0 or not _remote_checksums.has(frame) or not _sent_checksums.has(frame):
		return
	if _remote_checksums[frame] != _local_checksums[frame]:
		desync_frame = frame
		_write_desync_report(frame)


func _write_desync_report(frame: int) -> void:
	var path := "user://desync_%d.txt" % frame
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("Desync at frame %d (local player %d)\nlocal %d vs remote %d\n\n%s" % [
			frame, local_player, _local_checksums[frame], _remote_checksums[frame], state.debug_dump()])
	push_error("Online desync at frame %d. Report written to %s" % [frame, ProjectSettings.globalize_path(path)])


## Forgets data that's too old to matter.
func _prune() -> void:
	var oldest := state.frame - MAX_ROLLBACK - 2
	for dict in [_saved, _predicted]:
		for f in dict.keys():
			if f < oldest:
				dict.erase(f)
	var keep_inputs := state.frame - keep_input_frames
	for dict in [_local_inputs, _remote_inputs]:
		for f in dict.keys():
			if f < keep_inputs:
				dict.erase(f)
	for key in _played_events.keys():
		if _played_events[key] < oldest - 60:
			_played_events.erase(key)
	for dict in [_local_checksums, _sent_checksums, _remote_checksums]:
		for f in dict.keys():
			if f < state.frame - 1200:
				dict.erase(f)
