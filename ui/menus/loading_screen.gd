## Shown before every fight: who's fighting, a countdown, a tip, and a space
## for an ad. The fight loads in the background meanwhile.
##
## Stays up for Game.loading_seconds() (60 s) even when loading is done
## sooner, because the ad will need the time. With Game.LOADING_SKIPPABLE, a
## "Skip" button appears once the fight has loaded.
##
## Online, both players start their countdown when the match is agreed, and
## this screen keeps the connection alive meanwhile. Being a little apart is
## fine: the fight waits for the other player's first inputs.
extends Control

const TIPS := [
	"Hold back to block high and mid attacks. Down-back blocks lows.",
	"Throws beat blocking: press LP + LK up close.",
	"SP does a special move with one button: handy on a touch screen.",
	"Leaving a ranked match early counts as a loss.",
	"Rollback netcode hides lag by predicting your opponent's inputs.",
	"In Training, F3 shows frame advantage after each hit: + means it's your turn.",
]

## Set false in tests, so the screen doesn't change scenes by itself.
var auto_start := true
var duration := 0.0
var elapsed := 0.0

var _bar: ProgressBar
var _countdown: Label
var _skip: Button
var _loaded: PackedScene
var _leaving := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())
	duration = Game.loading_seconds()
	ResourceLoader.load_threaded_request(Game.FIGHT)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 60
	column.offset_right = -60
	column.offset_top = 30
	column.offset_bottom = -30
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	add_child(column)

	column.add_child(_centered(MenuStyle.label(Game.mode_name(), 22, MenuStyle.ACCENT)))
	var versus := HBoxContainer.new()
	versus.alignment = BoxContainer.ALIGNMENT_CENTER
	versus.add_theme_constant_override("separation", 40)
	versus.add_child(_fighter_card(0))
	versus.add_child(MenuStyle.label("VS", 64, MenuStyle.ACCENT))
	versus.add_child(_fighter_card(1))
	column.add_child(versus)

	# Where the ad goes. Ad SDKs draw their own view on top of the game, so
	# this panel just reserves the space (and names it, for the ad code).
	var ad := PanelContainer.new()
	ad.name = "AdSlot"
	ad.custom_minimum_size = Vector2(640, 110)
	ad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ad_box := StyleBoxFlat.new()
	ad_box.bg_color = Color(0, 0, 0, 0.35)
	ad_box.border_color = Color(1, 1, 1, 0.12)
	ad_box.set_border_width_all(2)
	ad_box.set_corner_radius_all(6)
	ad.add_theme_stylebox_override("panel", ad_box)
	ad.add_child(_centered(MenuStyle.label("Advertisement", 18, Color(MenuStyle.TEXT, 0.35))))
	column.add_child(ad)

	var tip := MenuStyle.label("💡 " + TIPS[randi() % TIPS.size()], 18)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_centered(tip))

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(640, 18)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = MenuStyle.ACCENT
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	column.add_child(_bar)
	_countdown = _centered(MenuStyle.label("", 22))
	column.add_child(_countdown)

	_skip = MenuStyle.button("Skip", _start_fight, 200)
	_skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip.visible = false
	column.add_child(_skip)
	_update_text()


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _fighter_card(side: int) -> VBoxContainer:
	var def := CharacterRegistry.get_def(Game.p1_id if side == 0 else Game.p2_id)
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = 380
	var name_label := _centered(MenuStyle.label(def.display_name.to_upper() if def else "?", 44))
	if def:
		name_label.add_theme_color_override("font_color", def.color.lightened(0.35))
	card.add_child(name_label)
	card.add_child(_centered(MenuStyle.label(_player_name(side), 22)))
	return card


func _player_name(side: int) -> String:
	match Game.mode:
		Game.Mode.VERSUS_CPU:
			return "You" if side == 0 else "CPU · level %d" % Game.cpu_level
		Game.Mode.TRAINING:
			return "You" if side == 0 else "Training dummy"
		Game.Mode.ONLINE:
			var mine := side == (0 if Game.online and Game.online.is_host else 1)
			if mine:
				return Account.username() if Account.is_logged_in() else "You (guest)"
			var theirs: String = Game.online.opponent_name if Game.online else ""
			return theirs if theirs != "" else "Guest"
	return "Player %d" % (side + 1)


func time_left() -> float:
	return maxf(duration - elapsed, 0.0)


func _process(delta: float) -> void:
	if _leaving:
		return
	elapsed += delta
	_keep_connection_alive()
	if _loaded == null and ResourceLoader.load_threaded_get_status(Game.FIGHT) == ResourceLoader.THREAD_LOAD_LOADED:
		_loaded = ResourceLoader.load_threaded_get(Game.FIGHT)
	_skip.visible = Game.LOADING_SKIPPABLE and _loaded != null
	_update_text()
	if auto_start and time_left() <= 0.0 and _loaded != null:
		_start_fight()


func _update_text() -> void:
	_bar.value = 100.0 if duration <= 0.0 else 100.0 * elapsed / duration
	_countdown.text = "The fight starts in %d s" % ceili(time_left()) if time_left() > 0.0 else "Get ready!"


## Online: keep receiving, so the connection doesn't time out, and notice if
## the other player leaves. Their early fight inputs are kept for the fight.
func _keep_connection_alive() -> void:
	if Game.mode != Game.Mode.ONLINE or Game.online == null:
		return
	var transport := Game.online.transport
	var keep: Array[PackedByteArray] = []
	for bytes in transport.poll():
		var msg := NetMessages.decode(bytes)
		if not msg.is_empty() and msg[0] == NetMessages.Type.BYE:
			_opponent_left()
			return
		keep.append(bytes)
	transport.requeue(keep)
	if not transport.is_open():
		_opponent_left()


func _opponent_left() -> void:
	_leaving = true
	_countdown.text = "Your opponent left. Returning to the menu…"
	get_tree().create_timer(3.0).timeout.connect(Game.go_to_main_menu)


func _start_fight() -> void:
	if _leaving or _loaded == null:
		return
	_leaving = true
	get_tree().change_scene_to_packed(_loaded)
