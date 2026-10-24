## Shared layout and behaviour for the account screens (log in, sign up,
## profile, ...): a centered column of labelled fields, error messages under
## the field at fault, a busy state while the server answers, and Back on
## Esc / the phone's back button.
##
## A screen extends this, calls build() and then the add_* functions, which
## add to `into` (the column, or a section()).
class_name FormScreen
extends Control

const WIDTH := 600

var column: VBoxContainer
## Where add_* puts new controls.
var into: VBoxContainer

var _fields := {}         # name -> {"edit": LineEdit/TextEdit, "error": Label}
var _buttons: Array[BaseButton] = []
var _last_submit: Button
var _notice: Label


func build(title: String, subtitle := "") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	center.add_child(margin)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = WIDTH
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	into = column

	column.add_child(MenuStyle.label(title, 44, MenuStyle.ACCENT))
	if subtitle != "":
		add_text(subtitle, 20)
	_notice = add_text(Game.notice, 20, MenuStyle.SUCCESS)
	_notice.visible = Game.notice != ""
	Game.notice = ""


## A group of controls that can be shown or hidden together. Later add_*
## calls go into it.
func section(gap := 18) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	if gap > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = gap
		column.add_child(spacer)
	column.add_child(box)
	into = box
	return box


func add_heading(text: String) -> Label:
	var l := MenuStyle.label(text, 28, MenuStyle.ACCENT)
	into.add_child(l)
	return l


func add_text(text: String, size := 18, color := MenuStyle.TEXT) -> Label:
	var l := MenuStyle.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(l)
	return l


## A titled text box, with its own error line underneath. `field_name`
## matches the server's field names, so its errors land in the right place.
func add_field(field_name: String, title: String, secret := false,
		keyboard := LineEdit.KEYBOARD_TYPE_DEFAULT, placeholder := "") -> LineEdit:
	into.add_child(MenuStyle.label(title, 20))
	var edit := MenuStyle.text_field(placeholder, secret, keyboard)
	into.add_child(edit)
	edit.text_submitted.connect(func(_text): _on_enter(edit))
	_add_error_line(field_name, edit)
	return edit


func add_text_area(field_name: String, title: String, placeholder := "") -> TextEdit:
	into.add_child(MenuStyle.label(title, 20))
	var edit := MenuStyle.text_area(placeholder)
	into.add_child(edit)
	_add_error_line(field_name, edit)
	return edit


func _add_error_line(field_name: String, edit: Control) -> void:
	var error := add_text("", 17, MenuStyle.ERROR)
	error.visible = false
	_fields[field_name] = {"edit": edit, "error": error}


## The main button of a form, with a status line above it for messages that
## aren't about one field.
func add_submit(text: String, on_pressed: Callable) -> Button:
	var status := add_text("", 18, MenuStyle.ERROR)
	status.visible = false
	var b := MenuStyle.button(text, on_pressed, WIDTH)
	b.set_meta("status", status)
	b.set_meta("text", text)
	into.add_child(b)
	_buttons.append(b)
	_last_submit = b
	return b


func add_button(text: String, on_pressed: Callable) -> Button:
	var b := MenuStyle.button(text, on_pressed, WIDTH)
	into.add_child(b)
	_buttons.append(b)
	return b


func add_link(text: String, on_pressed: Callable) -> Button:
	var b := MenuStyle.link(text, on_pressed)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	into.add_child(b)
	_buttons.append(b)
	return b


## The text in a field; trimmed unless it's a password.
func value(field_name: String) -> String:
	var edit: Control = _fields[field_name].edit
	if edit is LineEdit:
		return edit.text if edit.secret else edit.text.strip_edges()
	return (edit as TextEdit).text.strip_edges()


func set_value(field_name: String, text: String) -> void:
	_fields[field_name].edit.text = text


func field(field_name: String) -> Control:
	return _fields[field_name].edit


## Disables the buttons (and shows "Please wait…") while the server answers.
func set_busy(busy: bool, submit: Button = null) -> void:
	for b in _buttons:
		b.disabled = busy
	if submit == null:
		submit = _last_submit
	if submit:
		submit.text = "Please wait…" if busy else str(submit.get_meta("text"))


func clear_errors() -> void:
	for f in _fields.values():
		f.error.visible = false
	for b in _buttons:
		if b.has_meta("status"):
			b.get_meta("status").visible = false
	_notice.visible = false


## Shows an error under a field (checks done before asking the server).
func field_error(field_name: String, message: String) -> void:
	var f: Dictionary = _fields[field_name]
	f.error.text = message
	f.error.visible = true
	f.edit.grab_focus()


## Shows a failed server call: under the field it names when that field is
## on this form, otherwise on the submit button's status line.
## `field_map` renames server fields to this form's names.
func show_error(result: Dictionary, submit: Button = null, field_map := {}) -> void:
	var name_here: String = field_map.get(result.field, result.field)
	if name_here != "" and _fields.has(name_here) and _fields[name_here].edit.is_visible_in_tree():
		field_error(name_here, result.message)
	else:
		show_status(result.message, MenuStyle.ERROR, submit)


func show_status(message: String, color := MenuStyle.ERROR, submit: Button = null) -> void:
	if submit == null:
		submit = _last_submit
	var status: Label = submit.get_meta("status")
	status.text = message
	status.add_theme_color_override("font_color", color)
	status.visible = true


## What Back does; screens override it.
func go_back() -> void:
	Game.go_to_main_menu()


## Enter in a field moves to the next field, or presses the form's button
## after the last one.
func _on_enter(edit: LineEdit) -> void:
	var parent := edit.get_parent()
	for i in range(edit.get_index() + 1, parent.get_child_count()):
		var next := parent.get_child(i)
		if next is LineEdit and next.visible:
			next.grab_focus()
			return
		if next is Button and next.has_meta("status"):
			if not next.disabled:
				next.pressed.emit()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


# Same rules as the server (server/src/app.ts), checked here first so
# mistakes show up without a round trip. "" means OK.

static func username_problem(text: String) -> String:
	var re := RegEx.create_from_string("^[A-Za-z0-9_]{3,20}$")
	return "" if re.search(text) else "3–20 letters, numbers or _ (no spaces)."


static func email_problem(text: String) -> String:
	var re := RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return "" if re.search(text) else "Enter a valid email address."


static func password_problem(text: String) -> String:
	return "" if text.length() >= 8 else "At least 8 characters."
