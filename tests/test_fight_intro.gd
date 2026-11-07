## The intro before a fight (fighters walk in and talk) and the 3-2-1
## countdown that follows.
extends GutTest

const H := preload("res://tests/helpers.gd")

var defs: Array[CharacterDef] = []


func before_each():
	defs = [CharacterRegistry.get_def("tulbul_pandey"), CharacterRegistry.get_def("bogembo")]


func test_each_fighter_walks_up_to_the_camera_and_talks():
	var start := FightState.create(defs, true)
	var intro := FightIntro.new(start, defs)
	assert_true(intro.on_stage(0))
	assert_false(intro.on_stage(1), "P2 waits off screen at first")
	assert_eq(intro.fighter(0).state, FighterState.State.WALK_FORWARD)
	assert_eq(intro.fighter(0).pos_x, 0, "in the middle of the stage")
	assert_almost_eq(intro.depth(0), FightIntro.FAR_DEPTH, 0.01, "starts at the back")
	intro.frame = FightIntro.WALK_FRAMES / 2
	assert_between(intro.depth(0), FightIntro.FAR_DEPTH, FightIntro.NEAR_DEPTH, "coming towards the camera")

	intro.frame = FightIntro.WALK_FRAMES
	assert_almost_eq(intro.depth(0), FightIntro.NEAR_DEPTH, 0.01, "stopped close to the camera")
	assert_eq(intro.fighter(0).state, FighterState.State.IDLE)
	assert_eq(intro.speaker(), 0)
	assert_string_contains(intro.caption(), "TULBUL PANDEY")
	assert_string_contains(intro.caption(), defs[0].intro_line)

	intro.frame = FightIntro.PART_FRAMES + 1
	assert_false(intro.on_stage(0), "P1 has left the shot")
	assert_true(intro.on_stage(1))
	assert_eq(intro.speaker(), -1, "nobody talks while P2 walks up")
	assert_lt(intro.depth(1), FightIntro.NEAR_DEPTH)

	intro.frame = FightIntro.PART_FRAMES + FightIntro.WALK_FRAMES
	assert_eq(intro.speaker(), 1)
	assert_string_contains(intro.caption(), "Bogembo khush hua!")
	assert_false(intro.done())
	intro.skip()
	assert_true(intro.done())


func test_intro_is_short():
	assert_lt(FightIntro.TOTAL_FRAMES / 60.0, 6.0, "under 6 seconds")


func test_every_fighter_has_a_line():
	for def in CharacterRegistry.all():
		assert_ne(def.intro_line, "", def.id)


func test_countdown_3_2_1_then_fight():
	var state := FightState.create(defs, true)
	var hud := FightHud.new()
	add_child_autofree(hud)
	var seen: Array[String] = []
	for i in Rules.ready_frames(1) + 10:
		var text := hud._message_text(state, defs)
		if seen.is_empty() or seen[-1] != text:
			seen.append(text)
		H.run(state, defs, 1)
	assert_eq(seen, ["3", "2", "1", "FIGHT!"] as Array[String])
	assert_eq(state.phase, FightState.Phase.FIGHTING)


func test_ad_is_5_seconds():
	assert_eq(Game.LOADING_SECONDS, 5.0)
