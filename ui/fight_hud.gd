## A simple HUD: health bars, timer, round wins, round messages and a debug panel.
##
## 💡 Phase 3 replaces this with a styled HUD scene. Like every view, it only
## reads FightState and never changes it.
class_name FightHud
extends Control

const Phase := FightState.Phase
const BAR_SIZE := Vector2(460, 26)

var _bars: Array[ProgressBar] = []
var _wins: Array[Label] = []
var _timer: Label
var _message: Label
var _debug: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in 2:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size = BAR_SIZE
		bar.add_theme_stylebox_override("background", _box(Color(0.15, 0.05, 0.05, 0.85)))
		bar.add_theme_stylebox_override("fill", _box(Color(1.0, 0.8, 0.2)))
		if i == 1:
			bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN  # P2's bar empties towards the center
		add_child(bar)
		_bars.append(bar)

		var wins := _label(22)
		add_child(wins)
		_wins.append(wins)

	_timer = _label(40)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_timer)

	_message = _label(56)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)

	_debug = _label(13)
	add_child(_debug)


func show_state(state: FightState, defs: Array[CharacterDef], debug_lines: PackedStringArray) -> void:
	var w := size.x
	_timer.position = Vector2(w / 2 - 50, 8)
	_timer.size = Vector2(100, 50)
	_timer.text = str(ceili(state.round_timer / 60.0))
	_message.position = Vector2(0, size.y * 0.3)
	_message.size = Vector2(w, 140)
	_message.text = _message_text(state)
	_debug.position = Vector2(12, 84)
	_debug.text = "\n".join(debug_lines)

	for i in 2:
		var bar := _bars[i]
		bar.max_value = defs[i].max_health
		bar.value = state.fighters[i].health
		bar.position = Vector2(24 if i == 0 else w - 24 - BAR_SIZE.x, 18)
		_wins[i].text = "● ".repeat(state.wins[i]) + "○ ".repeat(maxi(0, Rules.WINS_TO_WIN_MATCH - state.wins[i]))
		_wins[i].position = Vector2(bar.position.x if i == 0 else bar.position.x + BAR_SIZE.x - 60, 48)


func _message_text(state: FightState) -> String:
	match state.phase:
		Phase.READY:
			return "ROUND %d" % state.round_number if state.phase_frame < 55 else "FIGHT!"
		Phase.ROUND_OVER:
			var ko := state.fighters[0].health == 0 or state.fighters[1].health == 0
			var headline := "K.O." if ko else "TIME"
			if state.phase_frame < 60:
				return headline
			return "DRAW" if state.round_winner < 0 else "P%d WINS THE ROUND" % (state.round_winner + 1)
		Phase.MATCH_OVER:
			var result := "DRAW GAME" if state.match_winner < 0 else "P%d WINS!" % (state.match_winner + 1)
			return result + "\n[Enter] rematch"
	return ""


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4 if font_size > 20 else 0)
	return l


func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	return box
