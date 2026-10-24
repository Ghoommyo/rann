## The messages two online players send each other.
##
## 💡 Each message is a small Array, turned into bytes with var_to_bytes.
## Objects are never decoded (bytes_to_var refuses them by default), so a
## malicious packet can't create code or resources on your machine.
##
##   HELLO     [game_version, data_hash, character_id, username]  reliable
##             (username is "" for a guest)
##   START     [p1_id, p2_id, input_delay]                 reliable, host → client
##   INPUT     [match, first_frame, bits: PackedInt32Array, ack]  unreliable
##   CHECKSUM  [match, frame, value]                       reliable
##   PING      [time_ms]   PONG [time_ms]                  unreliable
##   REMATCH   []          BYE []                          reliable
##   RANKED    [match, server_match_id]                    reliable, host → client
class_name NetMessages

enum Type { HELLO, START, INPUT, CHECKSUM, PING, PONG, REMATCH, BYE, RANKED }


static func encode(type: Type, payload: Array = []) -> PackedByteArray:
	var message: Array = [type]
	message.append_array(payload)
	return var_to_bytes(message)


## Returns [type, ...payload], or [] if the bytes aren't a valid message.
static func decode(bytes: PackedByteArray) -> Array:
	if bytes.size() < 4:  # too short to be a Godot-encoded value
		return []
	var value = bytes_to_var(bytes)
	if not (value is Array) or value.is_empty() or not (value[0] is int):
		return []
	if value[0] < 0 or value[0] >= Type.size():
		return []
	return value
