extends GutTest


func test_lerp_int_endpoints_and_middle():
	assert_eq(FixedMath.lerp_int(0, 1000, 0, 4), 0)
	assert_eq(FixedMath.lerp_int(0, 1000, 4, 4), 1000)
	assert_eq(FixedMath.lerp_int(0, 1000, 1, 4), 250)
	assert_eq(FixedMath.lerp_int(1000, -1000, 1, 2), 0)


func test_hash_mix_is_order_sensitive_and_32_bit():
	var a := FixedMath.hash_mix(FixedMath.hash_mix(FixedMath.HASH_SEED, 1), 2)
	var b := FixedMath.hash_mix(FixedMath.hash_mix(FixedMath.HASH_SEED, 2), 1)
	assert_ne(a, b, "swapping values must change the hash")
	assert_between(a, 0, 0xFFFFFFFF)


func test_hash_mix_handles_negative_values():
	var h := FixedMath.hash_mix(FixedMath.HASH_SEED, -1500)
	assert_between(h, 0, 0xFFFFFFFF)
	assert_ne(h, FixedMath.hash_mix(FixedMath.HASH_SEED, 1500))
