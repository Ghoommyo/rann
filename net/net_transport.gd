## How bytes get to the other player. The rollback session only talks to this
## interface, so the same session code runs over the real network
## (EnetTransport) and over a simulated one in tests (SimTransport).
class_name NetTransport
extends RefCounted


## Sends one packet. Reliable packets always arrive, in order; unreliable
## ones are faster but may be lost or arrive out of order.
func send(_bytes: PackedByteArray, _reliable: bool) -> void:
	pass


## Returns packets received since the last call. Call once per frame.
func poll() -> Array[PackedByteArray]:
	return []


## True while connected to the other player.
func is_open() -> bool:
	return false


func close() -> void:
	pass
