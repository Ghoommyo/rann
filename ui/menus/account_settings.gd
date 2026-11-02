## Account settings: change username, email or password, or deactivate the
## account. (A deactivated account is reactivated by logging in again.)
extends FormScreen

var _username_button: Button
var _email_button: Button
var _email_now: Label
var _email_sent: Label
var _email_confirm_step: VBoxContainer
var _email_confirm_button: Button
var _password_code_button: Button
var _password_step: VBoxContainer
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

	# Email, in two steps: a code goes to the new address, then it's entered here.
	section()
	add_heading("Email")
	_email_now = add_text("", 18)
	add_field("email", "New email", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	add_field("email_password", "Your password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	_email_button = add_submit("Send code to new email", _change_email)
	_email_confirm_step = section(0)
	_email_sent = add_text("", 18)
	add_field("email_code", "Code from that email", false, LineEdit.KEYBOARD_TYPE_NUMBER, "123456")
	_email_confirm_button = add_submit("Change email", _confirm_email)
	_email_confirm_step.visible = false
	_show_email()

	# Password, in two steps: a code goes to the account's email first.
	section()
	add_heading("Password")
	add_text("We'll email you a code to confirm it's you. Changing it logs you out on your other devices.", 18)
	_password_code_button = add_submit("Send code to my email", _send_password_code)
	_password_step = section(0)
	add_field("password_code", "Code from the email", false, LineEdit.KEYBOARD_TYPE_NUMBER, "123456")
	add_field("new_password", "New password", true, LineEdit.KEYBOARD_TYPE_PASSWORD, "At least 8 characters")
	add_field("confirm_password", "Confirm new password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	_password_button = add_submit("Change password", _change_password)
	_password_step.visible = false

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
	var result: Dictionary = await _call(_email_button, Account.change_email.bind(value("email"), value("email_password")),
		{"password": "email_password"})
	if result.ok:
		set_value("email_password", "")
		_email_sent.text = "We sent a code to %s. Your email changes once you enter it." % str(result.data.get("pending_email", value("email")))
		_email_confirm_step.visible = true
		MenuStyle.focus_later(field("email_code"))


func _confirm_email() -> void:
	clear_errors()
	if not _is_code(value("email_code")):
		field_error("email_code", "The code is 6 digits.")
		return
	if await _run(_email_confirm_button, Account.confirm_email_change.bind(value("email_code")),
			"Email changed.", {"code": "email_code"}):
		set_value("email_code", "")
		_email_confirm_step.visible = false
		_show_email()


func _show_email() -> void:
	var email := str(Account.user.get("email", ""))
	_email_now.text = "Now: %s" % email
	set_value("email", "")


func _send_password_code() -> void:
	clear_errors()
	var result: Dictionary = await _call(_password_code_button, Account.request_password_code, {})
	if result.ok:
		show_status("We sent a code to %s." % str(result.data.get("email", "your email")), MenuStyle.SUCCESS, _password_code_button)
		_password_code_button.set_meta("text", "Send a new code")
		_password_code_button.text = "Send a new code"
		_password_step.visible = true
		MenuStyle.focus_later(field("password_code"))


func _change_password() -> void:
	clear_errors()
	if not _is_code(value("password_code")):
		field_error("password_code", "The code is 6 digits.")
		return
	var problem := password_problem(value("new_password"))
	if problem != "":
		field_error("new_password", problem)
		return
	if value("confirm_password") != value("new_password"):
		field_error("confirm_password", "The passwords don't match.")
		return
	if await _run(_password_button, Account.change_password.bind(value("password_code"), value("new_password")),
			"Password changed.", {"code": "password_code"}):
		for f in ["password_code", "new_password", "confirm_password"]:
			set_value(f, "")


static func _is_code(text: String) -> bool:
	return text.is_valid_int() and text.length() == 6


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
