## The fight HUD: names, health bars with a damage trail, timer, round pips,
## fight-style meters, combo counters and round messages.
##
## 💡 Built in code so it works for any character: the meters come from each
## character's FightStyle.hud_values(), so a new style component shows up on
## the HUD automatically. Like every view, it only reads FightState.
class_name FightHud
extends Control

const Phase := FightState.Phase
const BAR_SIZE := Vector2(470, 24)
const MARGIN := 24.0
const HEALTH_COLOR := Color(1.0, 0.82, 0.25)
const TRAIL_COLOR := Color(0.9, 0.15, 0.1)
## Seconds before the red "recent damage" trail starts to drain.
const TRAIL_DELAY := 0.5

var _side: Array[Dictionary] = []  # per player: nodes + trail state
var _timer: Label
var _message: Label
var _debug: Label
var _notice: Label
var debug_visible := false
## A line of text under the timer (online status, disconnects, …).
var notice := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var trail := _bar(TRAIL_COLOR, Color(0.12, 0.04, 0.04, 0.9))
		var health := _bar(HEALTH_COLOR, Color(0, 0, 0, 0))
		var name_label := _label(20)
		var pips := _label(18)
		var combo := _label(34)
		combo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		var meters := VBoxContainer.new()
		meters.add_theme_constant_override("separation", 2)
		add_child(meters)
		if i == 1:
			trail.fill_mode = ProgressBar.FILL_END_TO_BEGIN  # P2's bar drains towards the center
			health.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		_side.append({"trail": trail, "health": health, "name": name_label, "pips": pips,
			"combo": combo, "meters": meters, "trail_value": -1.0, "trail_wait": 0.0,
			"combo_shown": 0, "combo_time": 0.0})

	_timer = _label(44)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message = _label(64)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug = _label(13)
	_debug.add_theme_constant_override("outline_size", 3)
	_notice = _label(20)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))


func show_state(state: FightState, defs: Array[CharacterDef], delta: float, debug_lines: PackedStringArray) -> void:
	var w := size.x
	for i in 2:
		_show_side(i, state, defs[i], delta, w)

	_timer.position = Vector2(w / 2 - 60, 6)
	_timer.size = Vector2(120, 56)
	_timer.text = "∞" if state.training else str(ceili(state.round_timer / 60.0))

	_message.position = Vector2(0, size.y * 0.28)
	_message.size = Vector2(w, 180)
	_message.text = _message_text(state, defs)

	_notice.text = notice
	_notice.position = Vector2(0, 112)
	_notice.size = Vector2(w, 30)

	_debug.visible = debug_visible
	_debug.position = Vector2(MARGIN, 150)
	_debug.text = "\n".join(debug_lines)


func _show_side(i: int, state: FightState, def: CharacterDef, delta: float, w: float) -> void:
	var s: Dictionary = _side[i]
	var f := state.fighters[i]
	var left := i == 0
	var x := MARGIN if left else w - MARGIN - BAR_SIZE.x

	for key in ["trail", "health"]:
		var bar: ProgressBar = s[key]
		bar.position = Vector2(x, 40)
		bar.max_value = def.max_health
	s.health.value = f.health

	# The red trail waits a moment after each hit, then drains to the real health.
	if s.trail_value < 0 or f.health > s.trail_value:
		s.trail_value = float(f.health)  # new round / refill: no trail
	if f.health < s.get("last_health", f.health):
		s.trail_wait = TRAIL_DELAY
	s.last_health = f.health
	s.trail_wait -= delta
	if s.trail_wait <= 0:
		s.trail_value = maxf(f.health, s.trail_value - def.max_health * 0.6 * delta)
	s.trail.value = s.trail_value

	s.name.text = def.display_name.to_upper()
	s.name.position = Vector2(x, 10)
	s.name.size = Vector2(BAR_SIZE.x, 28)
	s.name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	s.name.add_theme_color_override("font_color", def.color.lightened(0.3))

	s.pips.text = "◆ ".repeat(state.wins[i]) + "◇ ".repeat(maxi(0, Rules.WINS_TO_WIN_MATCH - state.wins[i]))
	s.pips.position = Vector2(x + (BAR_SIZE.x - 70 if left else 0), 66)

	_show_meters(s.meters, def.get_style().hud_values(f), Vector2(x, 70), left)
	_show_combo(s, state.fighters[1 - i].combo_hits, x, left, delta)


## Fight-style values: a thin bar per meter, or a line of text.
func _show_meters(box: VBoxContainer, values: Array[Dictionary], pos: Vector2, left: bool) -> void:
	while box.get_child_count() < values.size():
		var row := HBoxContainer.new()
		var label := _label(14, false)
		label.custom_minimum_size = Vector2(70, 0)
		var bar := _bar(Color(0.35, 0.75, 1.0), Color(0.05, 0.08, 0.15, 0.85), false)
		bar.custom_minimum_size = Vector2(180, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		row.add_child(bar)
		box.add_child(row)
	box.position = pos + Vector2(0 if left else BAR_SIZE.x - 260, 22)
	for j in box.get_child_count():
		var row: HBoxContainer = box.get_child(j)
		row.visible = j < values.size()
		if not row.visible:
			continue
		var v := values[j]
		var label: Label = row.get_child(0)
		var bar: ProgressBar = row.get_child(1)
		if v.has("text"):
			label.text = "%s: %s" % [v.label, v.text]
			bar.visible = false
		else:
			label.text = v.label
			bar.visible = true
			bar.max_value = v.max
			bar.value = v.value
			var full: bool = v.value >= v.max
			(bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = \
				Color(1.0, 0.45, 0.15) if full else Color(0.35, 0.75, 1.0)


## "3 HITS" next to the attacker while their combo is going, then fades.
func _show_combo(s: Dictionary, hits: int, x: float, left: bool, delta: float) -> void:
	if hits >= 2:
		s.combo_shown = hits
		s.combo_time = 1.2
	else:
		s.combo_time = maxf(0.0, s.combo_time - delta)
	var label: Label = s.combo
	label.visible = s.combo_time > 0 and s.combo_shown >= 2
	label.text = "%d HITS" % s.combo_shown
	label.modulate.a = clampf(s.combo_time / 0.4, 0.0, 1.0)
	label.position = Vector2(x + (0 if left else BAR_SIZE.x - 200), 220)
	label.size = Vector2(200, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT


func _message_text(state: FightState, defs: Array[CharacterDef]) -> String:
	match state.phase:
		Phase.READY:
			if state.phase_frame >= 55:
				return "FIGHT!"
			var last := Rules.WINS_TO_WIN_MATCH - 1
			if state.wins[0] == last and state.wins[1] == last:
				return "FINAL ROUND"
			return "ROUND %d" % state.round_number
		Phase.ROUND_OVER:
			var ko := state.fighters[0].health == 0 or state.fighters[1].health == 0
			if state.phase_frame < 60:
				return "K.O." if ko else "TIME"
			return "DRAW" if state.round_winner < 0 else "%s WINS" % defs[state.round_winner].display_name.to_upper()
		Phase.MATCH_OVER:
			if state.match_winner < 0:
				return "DRAW GAME"
			return "%s\nWINS THE MATCH" % defs[state.match_winner].display_name.to_upper()
	return ""


## Creates a label (added to the HUD unless `add` is false).
func _label(font_size: int, add := true) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6 if font_size > 20 else 3)
	if add:
		add_child(l)
	return l


func _bar(fill: Color, background: Color, add := true) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size = BAR_SIZE
	bar.add_theme_stylebox_override("background", _box(background))
	bar.add_theme_stylebox_override("fill", _box(fill))
	if add:
		add_child(bar)
	return bar


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	return box
