## A fake network for tests: two connected ends in the same process, with
## adjustable latency, jitter and packet loss.
##
## 💡 Testing netcode over a real network is slow and unpredictable. This
## simulates the bad parts (delay, packets arriving out of order, packets
## lost) in a repeatable way, using a seeded random generator.
##
## Time is counted in frames: each poll() call moves this end's clock one frame.
class_name SimTransport
extends NetTransport

var latency_frames := 0
var jitter_frames := 0
## Chance (0..1) that an unreliable packet is lost.
var loss := 0.0

## Weak reference: two ends pointing at each other with normal references
## would keep each other alive forever (a reference cycle = memory leak).
var _peer_ref: WeakRef
var _inbox: Array[Dictionary] = []  # {at, bytes}
var _clock := 0
var _last_reliable_at := 0
var _rng := RandomNumberGenerator.new()
var _open := true


## Makes two connected ends. Each direction uses the same settings.
static func make_pair(latency := 0, jitter := 0, loss_chance := 0.0, seed_value := 1) -> Array[SimTransport]:
	var a := SimTransport.new()
	var b := SimTransport.new()
	a._peer_ref = weakref(b)
	b._peer_ref = weakref(a)
	for t in [a, b]:
		t.latency_frames = latency
		t.jitter_frames = jitter
		t.loss = loss_chance
	a._rng.seed = seed_value
	b._rng.seed = seed_value + 1
	var pair: Array[SimTransport] = [a, b]
	return pair


func send(bytes: PackedByteArray, reliable: bool) -> void:
	var peer: SimTransport = _peer_ref.get_ref() if _peer_ref else null
	if not _open or peer == null:
		return
	if not reliable and _rng.randf() < loss:
		return  # lost
	var at := peer._clock + latency_frames + _rng.randi_range(0, jitter_frames)
	if reliable:
		# Reliable packets keep their order, like ENet's reliable channel.
		at = maxi(at, peer._last_reliable_at)
		peer._last_reliable_at = at
	peer._inbox.append({"at": at, "bytes": bytes})


func poll() -> Array[PackedByteArray]:
	_clock += 1
	var ready: Array[PackedByteArray] = []
	var waiting: Array[Dictionary] = []
	for packet in _inbox:
		if packet.at <= _clock:
			ready.append(packet.bytes)
		else:
			waiting.append(packet)
	_inbox = waiting
	return ready


func is_open() -> bool:
	return _open


func close() -> void:
	_open = false
