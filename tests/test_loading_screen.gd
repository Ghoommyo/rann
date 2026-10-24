## The loading screen counts down from Game.loading_seconds().
extends GutTest


func test_counts_down():
	Game.mode = Game.Mode.VERSUS_CPU
	var screen: Control = load(Game.LOADING).instantiate()
	screen.auto_start = false
	add_child_autofree(screen)
	assert_almost_eq(screen.time_left(), Game.LOADING_SECONDS, 0.01, "starts full")
	screen._process(1.5)
	assert_almost_eq(screen.time_left(), Game.LOADING_SECONDS - 1.5, 0.01)
	assert_string_contains(screen._countdown.text, "%d s" % ceili(Game.LOADING_SECONDS - 1.5))
	screen._process(Game.LOADING_SECONDS)
	assert_eq(screen.time_left(), 0.0)
	assert_eq(screen._countdown.text, "Get ready!")


func test_command_line_can_shorten_it():
	Game.cli.loading = 0.0
	assert_eq(Game.loading_seconds(), 0.0)
	Game.cli.loading = -1.0
	assert_eq(Game.loading_seconds(), Game.LOADING_SECONDS)


func test_has_an_ad_slot():
	var screen: Control = load(Game.LOADING).instantiate()
	screen.auto_start = false
	add_child_autofree(screen)
	assert_not_null(screen.find_child("AdSlot", true, false))
