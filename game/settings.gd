## Player settings, saved to user://settings.cfg. Registered as the
## "Settings" autoload.
##
## 💡 user:// is a per-app folder Godot gives every platform (on Android it's
## inside the app's private storage), so settings survive app updates.
##
## Settings are view/comfort only: none of them can change the simulation,
## so two online players with different settings still stay in sync.
extends Node

signal changed

enum Quality { LOW, MEDIUM, HIGH }
enum TouchMode { AUTO, ON, OFF }

const PATH := "user://settings.cfg"

## Default touch layout: button → [x, y] as fractions of the screen size.
const DEFAULT_LAYOUT := {
	"lp": [0.76, 0.70], "rp": [0.84, 0.56], "lk": [0.84, 0.84], "rk": [0.92, 0.70],
	"sp": [0.71, 0.88], "block": [0.62, 0.84],
}

var master_volume := 0.8       # 0..1
var quality := Quality.MEDIUM
var fps_limit := 60            # 30 saves battery; the simulation always runs at 60
var haptics := true
var touch_mode := TouchMode.AUTO
var touch_scale := 1.0         # button size multiplier
var touch_layout := DEFAULT_LAYOUT.duplicate(true)

var _path := PATH


func _ready() -> void:
	load_settings()
	apply()


## `path` lets tests use their own file.
func load_settings(path := PATH) -> void:
	_path = path
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return  # first run: keep defaults
	master_volume = clampf(cfg.get_value("audio", "master_volume", master_volume), 0.0, 1.0)
	quality = clampi(cfg.get_value("graphics", "quality", quality), 0, Quality.size() - 1) as Quality
	fps_limit = 30 if cfg.get_value("graphics", "fps_limit", fps_limit) == 30 else 60
	haptics = cfg.get_value("controls", "haptics", haptics)
	touch_mode = clampi(cfg.get_value("controls", "touch_mode", touch_mode), 0, TouchMode.size() - 1) as TouchMode
	touch_scale = clampf(cfg.get_value("controls", "touch_scale", touch_scale), 0.6, 1.6)
	var saved_layout = cfg.get_value("controls", "touch_layout", {})
	if saved_layout is Dictionary:
		for key in DEFAULT_LAYOUT:
			if saved_layout.has(key) and saved_layout[key] is Array and saved_layout[key].size() == 2:
				touch_layout[key] = [clampf(saved_layout[key][0], 0.0, 1.0), clampf(saved_layout[key][1], 0.0, 1.0)]


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fps_limit", fps_limit)
	cfg.set_value("controls", "haptics", haptics)
	cfg.set_value("controls", "touch_mode", touch_mode)
	cfg.set_value("controls", "touch_scale", touch_scale)
	cfg.set_value("controls", "touch_layout", touch_layout)
	cfg.save(_path)
	apply()
	changed.emit()


func reset_touch_layout() -> void:
	touch_layout = DEFAULT_LAYOUT.duplicate(true)
	touch_scale = 1.0


## Applies the settings that work globally (volume, frame cap, render scale).
## Stage-specific options (shadows, glow) are read by the stage itself.
func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	Engine.max_fps = fps_limit
	var viewport := get_viewport()
	if viewport:
		# 💡 Rendering fewer pixels and upscaling is the biggest speed-up on phones.
		viewport.scaling_3d_scale = [0.67, 0.85, 1.0][quality]
		viewport.msaa_3d = Viewport.MSAA_DISABLED if quality != Quality.HIGH else Viewport.MSAA_2X


## Whether the on-screen touch controls should be shown.
func show_touch_controls() -> bool:
	match touch_mode:
		TouchMode.ON: return true
		TouchMode.OFF: return false
	return OS.has_feature("mobile")


## A short vibration (phones only), e.g. when landing a hit.
func vibrate(ms: int) -> void:
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
