## Account settings: change username, email or password, or deactivate the
## account. (A deactivated account is reactivated by logging in again.)
extends FormScreen

var _username_button: Button
var _email_button: Button
var _password_button: Button
var _deactivate_button: Button


func _ready() -> void:
	if not Account.is_logged_in():
		Game.go_to.call_deferred(Game.LOGIN)
		return
	build("ACCOUNT SETTINGS")

	section()
	add_heading("Username")
	add_field("username", "New username", false, LineEdit.KEYBOARD_TYPE_DEFAULT, "3–20 letters, numbers or _")
	set_value("username", Account.username())
	_username_button = add_submit("Change username", _change_username)

	section()
	add_heading("Email")
	add_field("email", "New email", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	set_value("email", str(Account.user.get("email", "")))
	add_field("email_password", "Your password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	_email_button = add_submit("Change email", _change_email)

	section()
	add_heading("Password")
	add_field("current_password", "Current password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	add_field("new_password", "New password", true, LineEdit.KEYBOARD_TYPE_PASSWORD, "At least 8 characters")
	add_field("confirm_password", "Confirm new password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	_password_button = add_submit("Change password", _change_password)
	add_text("Logs you out on your other devices.", 16, Color(MenuStyle.TEXT, 0.7))

	section()
	add_heading("Deactivate account")
	add_text("Hides your profile and logs you out everywhere. Your rating and games are kept: log in again any time to reactivate it.", 18)
	add_field("deactivate_password", "Your password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	_deactivate_button = add_submit("Deactivate account", _deactivate)
	_deactivate_button.add_theme_stylebox_override("normal", _danger_box())

	section()
	var back := add_link("Back", go_back)
	MenuStyle.focus_later(back)


func _danger_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.45, 0.08, 0.06, 0.8)
	box.border_color = MenuStyle.ERROR
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	return box


func _change_username() -> void:
	clear_errors()
	var problem := username_problem(value("username"))
	if problem == "" and value("username") == Account.username():
		problem = "That's already your username."
	if problem != "":
		field_error("username", problem)
		return
	await _run(_username_button, Account.change_username.bind(value("username")), "Username changed.")


func _change_email() -> void:
	clear_errors()
	var problem := email_problem(value("email"))
	if problem != "":
		field_error("email", problem)
		return
	if value("email_password") == "":
		field_error("email_password", "Enter your password.")
		return
	if await _run(_email_button, Account.change_email.bind(value("email"), value("email_password")),
			"Email changed.", {"password": "email_password"}):
		set_value("email_password", "")


func _change_password() -> void:
	clear_errors()
	var problem := password_problem(value("new_password"))
	if problem != "":
		field_error("new_password", problem)
		return
	if value("confirm_password") != value("new_password"):
		field_error("confirm_password", "The passwords don't match.")
		return
	if await _run(_password_button, Account.change_password.bind(value("current_password"), value("new_password")),
			"Password changed."):
		for f in ["current_password", "new_password", "confirm_password"]:
			set_value(f, "")


func _deactivate() -> void:
	clear_errors()
	if value("deactivate_password") == "":
		field_error("deactivate_password", "Enter your password.")
		return
	var result: Dictionary = await _call(_deactivate_button, Account.deactivate.bind(value("deactivate_password")),
		{"password": "deactivate_password"})
	if result.ok:
		Game.notice = "Your account is deactivated. Log in again any time to reactivate it."
		Game.go_to(Game.LOGIN)


## Runs one form's server call; true when it worked.
func _run(button: Button, request: Callable, success: String, field_map := {}) -> bool:
	var result: Dictionary = await _call(button, request, field_map)
	if result.ok:
		show_status(success, MenuStyle.SUCCESS, button)
	return result.ok


func _call(button: Button, request: Callable, field_map: Dictionary) -> Dictionary:
	set_busy(true, button)
	var result: Dictionary = await request.call()
	if not is_inside_tree():
		return result
	set_busy(false, button)
	if not result.ok:
		show_error(result, button, field_map)
		if result.status == 401 and not Account.is_logged_in():
			Game.notice = "Please log in again."
			Game.go_to(Game.LOGIN)
	return result
