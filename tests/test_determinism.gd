## 💡 The most important test in the project. If it fails, online play
## (Phase 4) would desync. It runs the same random inputs twice and checks
## the results match exactly.
extends GutTest

const FRAMES := 3000  # long enough for KOs and round changes


## Makes a reproducible sequence of random input pairs. Each input is held
## for a few frames, like a human would.
func _random_inputs(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var inputs := []
	var held := [0, 0]
	for i in FRAMES:
		for p in 2:
			if rng.randi_range(0, 7) == 0:
				held[p] = rng.randi_range(0, 255)  # any directions + buttons
		inputs.append([held[0], held[1]])
	return inputs


func _play(inputs: Array) -> FightState:
	var defs := TestHelpers.dummy_defs()
	var state := FightState.create(defs)
	for pair in inputs:
		MatchSim.step(state, defs, pair[0], pair[1])
	return state


func test_same_inputs_same_result():
	for seed_value in [1, 42, 1234]:
		var inputs := _random_inputs(seed_value)
		var a := _play(inputs)
		var b := _play(inputs)
		assert_eq(a.frame, FRAMES)
		assert_eq(a.checksum(), b.checksum(), "seed %d diverged" % seed_value)


func test_different_inputs_different_result():
	assert_ne(_play(_random_inputs(1)).checksum(), _play(_random_inputs(2)).checksum())


func test_copy_then_continue_matches_original():
	# Simulates what rollback does: snapshot mid-fight, keep playing from the copy.
	var inputs := _random_inputs(7)
	var defs := TestHelpers.dummy_defs()
	var original := FightState.create(defs)
	var snapshot: FightState
	for i in FRAMES:
		if i == FRAMES / 2:
			snapshot = original.copy()
		MatchSim.step(original, defs, inputs[i][0], inputs[i][1])
	for i in range(FRAMES / 2, FRAMES):
		MatchSim.step(snapshot, defs, inputs[i][0], inputs[i][1])
	assert_eq(snapshot.checksum(), original.checksum())


func test_checksum_covers_style_data():
	var defs := TestHelpers.dummy_defs()
	var a := FightState.create(defs)
	var b := a.copy()
	assert_eq(a.checksum(), b.checksum())
	b.fighters[0].style_data["meter.value"] = 5
	assert_ne(a.checksum(), b.checksum())
