extends GutTest

const PATH := "user://settings_test.cfg"

var saved := {}


func before_each():
	# Remember the real settings so the test doesn't change them.
	saved = {"q": Settings.quality, "fps": Settings.fps_limit, "scale": Settings.touch_scale,
		"layout": Settings.touch_layout.duplicate(true), "haptics": Settings.haptics,
		"volume": Settings.master_volume, "mode": Settings.touch_mode}


func after_each():
	Settings.quality = saved.q
	Settings.fps_limit = saved.fps
	Settings.touch_scale = saved.scale
	Settings.touch_layout = saved.layout
	Settings.haptics = saved.haptics
	Settings.master_volume = saved.volume
	Settings.touch_mode = saved.mode
	Settings.load_settings()  # back to the real file path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_round_trip():
	Settings.load_settings(PATH)
	Settings.quality = Settings.Quality.LOW
	Settings.fps_limit = 30
	Settings.touch_scale = 1.3
	Settings.touch_layout["lp"] = [0.5, 0.5]
	Settings.haptics = false
	Settings.save()
	Settings.reset_touch_layout()
	Settings.quality = Settings.Quality.HIGH
	Settings.load_settings(PATH)
	assert_eq(Settings.quality, Settings.Quality.LOW)
	assert_eq(Settings.fps_limit, 30)
	assert_almost_eq(Settings.touch_scale, 1.3, 0.001)
	assert_eq(Settings.touch_layout["lp"], [0.5, 0.5])
	assert_false(Settings.haptics)


func test_bad_values_are_clamped():
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", 99)
	cfg.set_value("controls", "touch_scale", 50.0)
	cfg.set_value("controls", "touch_layout", {"lp": [5.0, -2.0], "rk": "garbage"})
	cfg.save(PATH)
	Settings.load_settings(PATH)
	assert_eq(Settings.quality, Settings.Quality.HIGH)
	assert_almost_eq(Settings.touch_scale, 1.6, 0.001)
	assert_eq(Settings.touch_layout["lp"], [1.0, 0.0])
