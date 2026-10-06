## Connects two players and agrees on the match before it starts.
##
## Handshake:
##   1. both connect (host waits, client joins by IP)
##   2. both send HELLO [game version, data hash, character]
##   3. versions or data differ → refuse with a clear message
##   4. the host decides the match and sends START [p1, p2, input delay]
## The host is always P1 (left side), the client P2.
##
## Lives in the Game autoload, so the connection survives the scene change
## from the lobby to the fight.
class_name OnlineConnection
extends RefCounted

enum Status { IDLE, WAITING_FOR_PLAYER, CONNECTING, HANDSHAKE, READY, FAILED }

const CONNECT_TIMEOUT_MS := 10000

var status := Status.IDLE
var error_text := ""
var transport := EnetTransport.new()
var is_host := false
var my_character := ""
var input_delay := 2
# Agreed match settings (valid once READY)
var p1_id := ""
var p2_id := ""

var _hello_sent := false
var _started_ms := 0


func host(character_id: String, delay: int, port := EnetTransport.DEFAULT_PORT) -> void:
	is_host = true
	my_character = character_id
	input_delay = delay
	var err := transport.host(port)
	if err != OK:
		_fail("Couldn't open port %d (%s). Is another game already hosting?" % [port, error_string(err)])
		return
	status = Status.WAITING_FOR_PLAYER


func join(address: String, character_id: String, port := EnetTransport.DEFAULT_PORT) -> void:
	is_host = false
	my_character = character_id
	var err := transport.join(address.strip_edges(), port)
	if err != OK:
		_fail("Couldn't connect to %s (%s)" % [address, error_string(err)])
		return
	status = Status.CONNECTING
	_started_ms = Time.get_ticks_msec()


## Call every frame while in the lobby.
func update() -> void:
	if status in [Status.IDLE, Status.READY, Status.FAILED]:
		return
	var packets := transport.poll()
	if status == Status.CONNECTING and Time.get_ticks_msec() - _started_ms > CONNECT_TIMEOUT_MS:
		_fail("No answer from the host. Check the IP address, and that the host forwarded UDP port %d." %
			EnetTransport.DEFAULT_PORT)
		return
	if transport.is_open() and not _hello_sent:
		_hello_sent = true
		status = Status.HANDSHAKE
		transport.send(NetMessages.encode(NetMessages.Type.HELLO,
			[Game.GAME_VERSION, Game.data_hash(), my_character]), true)

	var leftover: Array[PackedByteArray] = []
	for bytes in packets:
		var msg := NetMessages.decode(bytes)
		if msg.is_empty():
			continue
		match msg[0]:
			NetMessages.Type.HELLO:
				_on_hello(msg)
			NetMessages.Type.START:
				if not is_host:
					p1_id = msg[1]
					p2_id = msg[2]
					input_delay = msg[3]
					status = Status.READY
			_:
				leftover.append(bytes)  # e.g. early match inputs: keep them for the session
	transport.requeue(leftover)


func _on_hello(msg: Array) -> void:
	var version: String = msg[1]
	var data: String = msg[2]
	var their_character: String = msg[3]
	if version != Game.GAME_VERSION:
		_fail("Version mismatch: you have %s, they have %s. Both players need the same version." % [
			Game.GAME_VERSION, version])
		return
	if data != Game.data_hash():
		_fail("Game data differs (characters or moves were changed). Both players need the same build.")
		return
	if CharacterRegistry.get_def(their_character) == null:
		_fail("Opponent picked an unknown character '%s'." % their_character)
		return
	if is_host:
		p1_id = my_character
		p2_id = their_character
		transport.send(NetMessages.encode(NetMessages.Type.START, [p1_id, p2_id, input_delay]), true)
		status = Status.READY


func status_text() -> String:
	match status:
		Status.WAITING_FOR_PLAYER: return "Waiting for a player to join…"
		Status.CONNECTING: return "Connecting…"
		Status.HANDSHAKE: return "Connected. Checking versions…"
		Status.READY: return "Ready!"
		Status.FAILED: return error_text
	return ""


func close() -> void:
	if transport.is_open():
		transport.send(NetMessages.encode(NetMessages.Type.BYE), true)
		transport.poll()  # flush
	transport.close()
	status = Status.IDLE


func _fail(text: String) -> void:
	error_text = text
	status = Status.FAILED
	transport.close()
