extends GutTest

const H := preload("res://tests/helpers.gd")
const S := FighterState.State

var defs: Array[CharacterDef]
var state: FightState


func before_each():
	defs = [CharacterRegistry.get_def("kael"), CharacterRegistry.get_def("mira")]
	state = FightState.create(defs)


func test_from_numpad_round_trip():
	for facing in [1, -1]:
		for n in range(1, 10):
			assert_eq(InputFrame.to_numpad(InputFrame.from_numpad(n, facing), facing), n)


func test_performs_motion_input():
	# CPU plays P1 (Kael) and performs the quarter-circle dashing punch.
	var cpu := CpuOpponent.new()
	var kael := defs[0]
	cpu.perform(kael.moves[kael.find_move("dash_punch")], state.fighters[0].facing)
	for i in 4:
		MatchSim.step(state, defs, cpu.next_input(state, defs, 0), 0)
	var f := state.fighters[0]
	assert_eq(f.state, S.ATTACK)
	assert_eq(kael.moves[f.move_index].id, "dash_punch")


func test_blocks_a_seen_attack():
	var cpu := CpuOpponent.new(CpuOpponent.Level.HARD)
	cpu.block_chance = 1.0
	cpu.aggression = 0.0
	H.place_p2_at_wall(state, defs, 700)
	var blocked := false
	for step in 40:
		var p1 := InputFrame.RK if step == 0 else 0  # Kael body kick, i14
		MatchSim.step(state, defs, p1, cpu.next_input(state, defs, 1))
		blocked = blocked or state.fighters[1].state == S.BLOCKSTUN
	assert_true(blocked)
	assert_eq(state.fighters[1].health, defs[1].max_health)


func test_breaks_throws():
	var cpu := CpuOpponent.new(CpuOpponent.Level.HARD)
	cpu.throw_break_chance = 1.0
	cpu.aggression = 0.0
	H.place_p2_at_wall(state, defs, 600)
	for step in 80:
		var p1 := (InputFrame.LP | InputFrame.LK) if step == 0 else 0
		MatchSim.step(state, defs, p1, cpu.next_input(state, defs, 1))
	assert_eq(state.fighters[1].health, defs[1].max_health, "throw broken")


## Two CPUs with the same seeds must play exactly the same match.
func test_cpu_is_deterministic():
	var results := []
	for run in 2:
		var s := FightState.create(defs, true)
		var cpu1 := CpuOpponent.new(CpuOpponent.Level.HARD, 11)
		var cpu2 := CpuOpponent.new(CpuOpponent.Level.NORMAL, 22)
		for i in 3000:
			MatchSim.step(s, defs, cpu1.next_input(s, defs, 0), cpu2.next_input(s, defs, 1))
		results.append(s.checksum())
	assert_eq(results[0], results[1])


func test_cpu_vs_cpu_finishes_a_match():
	for level in [CpuOpponent.Level.EASY, CpuOpponent.Level.HARD]:
		var s := FightState.create(defs, true)
		var cpu1 := CpuOpponent.new(level, 5)
		var cpu2 := CpuOpponent.new(level, 6)
		var hits := 0
		for i in 30000:
			MatchSim.step(s, defs, cpu1.next_input(s, defs, 0), cpu2.next_input(s, defs, 1))
			for e in s.events:
				if e.type == FightState.Event.HIT:
					hits += 1
			if s.phase == FightState.Phase.MATCH_OVER:
				break
		assert_eq(s.phase, FightState.Phase.MATCH_OVER, "level %d match finished" % level)
		assert_gt(hits, 10, "level %d CPUs actually fight" % level)
		gut.p("level %d: %d hits, wins %s, %d frames" % [level, hits, s.wins, s.frame])
