## Two rollback sessions talking over a simulated network must end up with
## exactly the same match as playing the same inputs offline.
extends GutTest

const FRAMES := 1200

var defs: Array[CharacterDef]


func before_all():
	defs = [CharacterRegistry.get_def("kael"), CharacterRegistry.get_def("mira")]


## Plays a match between two sessions. Each side holds random inputs for a few
## frames, like a human. Returns [session_a, session_b].
func _play(latency: int, jitter: int, loss: float, delay: int, frames := FRAMES) -> Array:
	var pair := SimTransport.make_pair(latency, jitter, loss, 7)
	var a := RollbackSession.new(defs, 0, delay, pair[0], FightState.create(defs, true))
	var b := RollbackSession.new(defs, 1, delay, pair[1], FightState.create(defs, true))
	for s in [a, b]:
		s.keep_input_frames = 100000
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var held := [0, 0]
	var guard := 0
	while (a.state.frame < frames or b.state.frame < frames) and guard < frames * 4:
		guard += 1
		for p in 2:
			if rng.randi_range(0, 5) == 0:
				held[p] = rng.randi_range(0, 255)
		if a.state.frame < frames:
			a.tick(held[0])
		if b.state.frame < frames:
			b.tick(held[1])
	# Keep exchanging packets until both have confirmed everything.
	for i in 60:
		a.tick(0)
		b.tick(0)
	return [a, b]


## Replays the confirmed inputs offline and returns the checksum at `frame`.
func _offline_checksum(session: RollbackSession, frame: int) -> int:
	var s := FightState.create(defs, true)
	for f in frame:
		var inputs := session.confirmed_inputs(f)
		MatchSim.step(s, defs, inputs[0], inputs[1])
	return s.checksum()


func _check(latency: int, jitter: int, loss: float, delay: int) -> Array:
	var sessions := _play(latency, jitter, loss, delay)
	var a: RollbackSession = sessions[0]
	var b: RollbackSession = sessions[1]
	var label := "latency %d, jitter %d, loss %.0f%%, delay %d" % [latency, jitter, loss * 100, delay]
	var ca := a.confirmed_checksum(FRAMES)
	var cb := b.confirmed_checksum(FRAMES)
	assert_ne(ca, -1, "%s: A confirmed frame %d" % [label, FRAMES])
	assert_eq(ca, cb, "%s: both players agree" % label)
	assert_eq(ca, _offline_checksum(a, FRAMES), "%s: matches an offline replay" % label)
	assert_eq(a.desync_frame, -1, label)
	assert_eq(b.desync_frame, -1, label)
	gut.p("%s → rollbacks %d (max %d frames), stalls %d/%d" % [
		label, a.total_rollbacks + b.total_rollbacks, maxi(a.max_rollback_frames, b.max_rollback_frames),
		a.stalls, b.stalls])
	return sessions


func test_perfect_network():
	var s := _check(0, 0, 0.0, 2)
	assert_eq(s[0].total_rollbacks + s[1].total_rollbacks, 0, "no lag beyond the input delay: no rollbacks")


func test_lag_causes_rollbacks_but_same_result():
	var s := _check(4, 0, 0.0, 1)
	assert_gt(s[0].total_rollbacks + s[1].total_rollbacks, 0)
	assert_lte(maxi(s[0].max_rollback_frames, s[1].max_rollback_frames), RollbackSession.MAX_ROLLBACK)


func test_bad_network_jitter_and_loss():
	_check(6, 4, 0.1, 2)


func test_very_high_latency_stalls_but_stays_in_sync():
	var s := _check(10, 2, 0.05, 2)
	assert_gt(s[0].stalls + s[1].stalls, 0, "latency beyond the rollback window forces waiting")


func test_no_input_delay():
	_check(3, 1, 0.0, 0)


func test_stalls_when_opponent_silent():
	var pair := SimTransport.make_pair()
	var a := RollbackSession.new(defs, 0, 2, pair[0], FightState.create(defs))
	var advanced := 0
	for i in 30:
		if a.tick(0):
			advanced += 1
	assert_eq(advanced, RollbackSession.MAX_ROLLBACK + 2, "runs ahead at most the rollback window")


func test_events_are_not_repeated_after_rollback():
	# Lag + attacks: count HIT events seen by the view vs. hits in an offline replay.
	var pair := SimTransport.make_pair(5, 2, 0.0, 3)
	var a := RollbackSession.new(defs, 0, 1, pair[0], FightState.create(defs))
	var b := RollbackSession.new(defs, 1, 1, pair[1], FightState.create(defs))
	a.keep_input_frames = 100000
	a.state.fighters[1].pos_x = a.state.fighters[0].pos_x + 700
	b.state.fighters[1].pos_x = b.state.fighters[0].pos_x + 700
	var seen := 0
	for f in 400:
		var press := InputFrame.RK if f % 40 == 0 else 0  # mid kick: hits standing and crouching
		a.tick(press)
		b.tick(InputFrame.DOWN if (f / 7) % 2 == 0 else 0)  # P2 keeps changing input → rollbacks
		for e in a.take_events():
			if e.type == FightState.Event.HIT or e.type == FightState.Event.BLOCK:
				seen += 1
	assert_gt(a.total_rollbacks, 0)
	# Offline replay of what A finally confirmed.
	var s := FightState.create(defs)
	s.fighters[1].pos_x = s.fighters[0].pos_x + 700
	var real := 0
	for f in a.confirmed_frame() + 1:
		var inputs := a.confirmed_inputs(f)
		MatchSim.step(s, defs, inputs[0], inputs[1])
		for e in s.events:
			if e.type == FightState.Event.HIT or e.type == FightState.Event.BLOCK:
				real += 1
	assert_gte(real, 2, "the scenario must produce some contacts")
	# Rollbacks can make a predicted hit "un-happen", so allow seen ≥ real, but never duplicates.
	assert_between(seen, real, real + 2, "each contact shown once (seen %d, real %d)" % [seen, real])


func test_rollback_cost():
	var s := FightState.create(defs)
	var start := Time.get_ticks_usec()
	var runs := 200
	for i in runs:
		var saved := s.copy()
		s = saved.copy()
		for f in RollbackSession.MAX_ROLLBACK:
			MatchSim.step(s, defs, InputFrame.RIGHT, InputFrame.LP if f % 2 else 0)
	var per_rollback_ms := (Time.get_ticks_usec() - start) / 1000.0 / runs
	gut.p("worst-case rollback (restore + %d frames): %.3f ms" % [RollbackSession.MAX_ROLLBACK, per_rollback_ms])
	assert_lt(per_rollback_ms, 8.0, "must fit easily in a 16.7 ms frame")
