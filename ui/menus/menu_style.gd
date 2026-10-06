## Shared look for menu screens, so every screen is styled the same way.
class_name MenuStyle

const BG_TOP := Color(0.08, 0.06, 0.14)
const BG_BOTTOM := Color(0.35, 0.12, 0.1)
const ACCENT := Color(1.0, 0.6, 0.2)
const TEXT := Color(0.96, 0.92, 0.86)


## A full-screen gradient background.
static func background() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, BG_TOP)
	gradient.set_color(1, BG_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func label(text: String, font_size: int, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6 if font_size >= 30 else 2)
	return l


## A large, touch-friendly button.
static func button(text: String, on_pressed: Callable, min_width := 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.15)))
	b.add_theme_stylebox_override("hover", _box(Color(0.25, 0.12, 0.05, 0.8), ACCENT))
	b.add_theme_stylebox_override("focus", _box(Color(0.25, 0.12, 0.05, 0.8), ACCENT))
	b.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.3), ACCENT))
	b.add_theme_stylebox_override("disabled", _box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.05)))
	b.pressed.connect(on_pressed)
	return b


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box
