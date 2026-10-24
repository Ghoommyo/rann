## Shared look for menu screens, so every screen is styled the same way.
class_name MenuStyle

const BG_TOP := Color(0.08, 0.06, 0.14)
const BG_BOTTOM := Color(0.35, 0.12, 0.1)
const ACCENT := Color(1.0, 0.6, 0.2)
const TEXT := Color(0.96, 0.92, 0.86)
const ERROR := Color(1.0, 0.5, 0.45)
const SUCCESS := Color(0.55, 0.95, 0.6)


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


## Gives `control` keyboard/gamepad focus once the screen is ready, unless the
## screen has already been left by then.
static func focus_later(control: Control) -> void:
	var ref: WeakRef = weakref(control)  # a plain capture would complain if it's freed first
	(func():
		var c: Control = ref.get_ref()
		if c and c.is_inside_tree():
			c.grab_focus()).call_deferred()


## A large, touch-friendly button.
static func button(text: String, on_pressed: Callable, min_width := 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	style_button(b)
	b.pressed.connect(on_pressed)
	return b


## Gives any button (Button, MenuButton, ...) the menu look.
static func style_button(b: BaseButton) -> void:
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.15)))
	b.add_theme_stylebox_override("hover", _box(Color(0.25, 0.12, 0.05, 0.8), ACCENT))
	b.add_theme_stylebox_override("focus", _box(Color(0.25, 0.12, 0.05, 0.8), ACCENT))
	b.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.3), ACCENT))
	b.add_theme_stylebox_override("disabled", _box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.05)))


## A small text-only button, e.g. "Forgot password?".
static func link(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.custom_minimum_size.y = 44
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", ACCENT)
	b.add_theme_color_override("font_hover_color", ACCENT.lightened(0.4))
	b.add_theme_color_override("font_focus_color", ACCENT.lightened(0.4))
	b.add_theme_color_override("font_pressed_color", ACCENT.darkened(0.2))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), ACCENT))
	b.pressed.connect(on_pressed)
	return b


## A one-line text box. 💡 On phones, `keyboard` picks which on-screen
## keyboard opens (e.g. one with "@" for emails).
static func text_field(placeholder := "", secret := false,
		keyboard := LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var f := LineEdit.new()
	f.placeholder_text = placeholder
	f.secret = secret
	f.virtual_keyboard_type = keyboard
	f.custom_minimum_size.y = 56
	_style_text_box(f)
	return f


## A multi-line text box, e.g. for the profile bio.
static func text_area(placeholder := "") -> TextEdit:
	var t := TextEdit.new()
	t.placeholder_text = placeholder
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.custom_minimum_size.y = 140
	_style_text_box(t)
	return t


static func _style_text_box(c: Control) -> void:
	c.add_theme_font_size_override("font_size", 24)
	c.add_theme_color_override("font_color", TEXT)
	c.add_theme_color_override("font_placeholder_color", Color(TEXT, 0.4))
	c.add_theme_color_override("caret_color", ACCENT)
	var normal := _box(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.2))
	var focus := _box(Color(0, 0, 0, 0.6), ACCENT)
	for box in [normal, focus]:
		box.content_margin_top = 8
		box.content_margin_bottom = 8
	c.add_theme_stylebox_override("normal", normal)
	c.add_theme_stylebox_override("focus", focus)
	c.add_theme_stylebox_override("read_only", normal)


## Three bars: the "menu" icon (drawn here, so it doesn't depend on a font
## having the ☰ character).
static func menu_icon(size := 28) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var bar := maxi(3, size / 8)
	for i in 3:
		img.fill_rect(Rect2i(2, int(size * (0.18 + 0.32 * i)), size - 4, bar), TEXT)
	return ImageTexture.create_from_image(img)


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 16
	box.content_margin_right = 16
	return box
