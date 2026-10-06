## The real network: a direct UDP connection between two games using ENet
## (built into Godot). One player hosts, the other joins by IP address.
##
## 💡 Only the host needs to be reachable. On the same Wi-Fi that just works;
## over the internet the host must forward UDP port 7777 on their router
## (matchmaking through a server, in a later step, removes that need).
##
## A lag simulator can delay, jitter and drop outgoing packets, to test
## rollback on a perfect local network (e.g. `--net-lag=120`).
class_name EnetTransport
extends NetTransport

const DEFAULT_PORT := 7777
const RELIABLE_CHANNEL := 0
const UNRELIABLE_CHANNEL := 1

var is_host := false
# Lag simulator (outgoing packets only)
var lag_ms := 0
var jitter_ms := 0
var loss := 0.0

var _peer := ENetMultiplayerPeer.new()
var _connected := false
var _delayed: Array[Dictionary] = []  # {at, bytes, reliable}
var _requeued: Array[PackedByteArray] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	# Methods rather than lambdas: a lambda capturing `self`, stored in a signal
	# of an object `self` owns, would form a reference cycle and leak.
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func _on_peer_connected(_id: int) -> void:
	_connected = true


func _on_peer_disconnected(_id: int) -> void:
	_connected = false


func host(port := DEFAULT_PORT) -> Error:
	is_host = true
	return _peer.create_server(port, 1, 2)


func join(address: String, port := DEFAULT_PORT) -> Error:
	is_host = false
	return _peer.create_client(address, port, 2)


func send(bytes: PackedByteArray, reliable: bool) -> void:
	if lag_ms > 0 or jitter_ms > 0 or loss > 0.0:
		if not reliable and _rng.randf() < loss:
			return
		var at := Time.get_ticks_msec() + lag_ms + _rng.randi_range(0, jitter_ms)
		_delayed.append({"at": at, "bytes": bytes, "reliable": reliable})
		return
	_put(bytes, reliable)


func poll() -> Array[PackedByteArray]:
	var now := Time.get_ticks_msec()
	var still_waiting: Array[Dictionary] = []
	for packet in _delayed:
		if packet.at <= now:
			_put(packet.bytes, packet.reliable)
		else:
			still_waiting.append(packet)
	_delayed = still_waiting

	_peer.poll()
	var packets := _requeued
	_requeued = []
	while _peer.get_available_packet_count() > 0:
		packets.append(_peer.get_packet())
	return packets


## Gives packets back so the next poll() returns them again (used when the
## lobby hands the connection over to the match).
func requeue(packets: Array[PackedByteArray]) -> void:
	_requeued.append_array(packets)


func is_open() -> bool:
	return _connected


func close() -> void:
	_connected = false
	_peer.close()


func _put(bytes: PackedByteArray, reliable: bool) -> void:
	if not _connected:
		return
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable \
		else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	_peer.transfer_channel = RELIABLE_CHANNEL if reliable else UNRELIABLE_CHANNEL
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)  # there's only one other player
	_peer.put_packet(bytes)
