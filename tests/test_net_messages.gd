extends GutTest


func test_round_trip():
	var bits := PackedInt32Array([1, 2, 3, 255])
	var msg := NetMessages.decode(NetMessages.encode(NetMessages.Type.INPUT, [40, bits, 37]))
	assert_eq(msg[0], NetMessages.Type.INPUT)
	assert_eq(msg[1], 40)
	assert_eq(msg[2], bits)
	assert_eq(msg[3], 37)


func test_rejects_garbage():
	assert_eq(NetMessages.decode(PackedByteArray()), [])
	assert_eq(NetMessages.decode(PackedByteArray([1, 2, 3])), [])
	assert_eq(NetMessages.decode(var_to_bytes("hello")), [])
	assert_eq(NetMessages.decode(var_to_bytes([999])), [], "unknown type")
