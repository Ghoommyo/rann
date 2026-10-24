## Forgot password, in two steps: the player enters their email and gets a
## 6-digit code by email, then enters the code and a new password.
extends FormScreen

var _step_email: VBoxContainer
var _step_code: VBoxContainer
var _send: Button
var _reset: Button


func _ready() -> void:
	build("FORGOT PASSWORD")
	_step_email = section(0)
	add_text("Enter your account's email and we'll send you a code.")
	var email := add_field("email", "Email", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	_send = add_submit("Send code", _send_code)

	_step_code = section(0)
	add_text("If that email has an account, a 6-digit code is on its way. It works for 15 minutes.")
	add_field("code", "Code", false, LineEdit.KEYBOARD_TYPE_NUMBER, "123456")
	add_field("new_password", "New password", true, LineEdit.KEYBOARD_TYPE_PASSWORD, "At least 8 characters")
	add_field("confirm_password", "Confirm new password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	_reset = add_submit("Change password", _reset_password)
	add_link("Send a new code", _show_step.bind(0))
	_step_code.visible = false

	section(0)
	add_link("Back to log in", go_back)
	MenuStyle.focus_later(email)


func _show_step(step: int) -> void:
	clear_errors()
	_step_email.visible = step == 0
	_step_code.visible = step == 1
	MenuStyle.focus_later(field("email") if step == 0 else field("code"))


func _send_code() -> void:
	clear_errors()
	var problem := email_problem(value("email"))
	if problem != "":
		field_error("email", problem)
		return
	set_busy(true, _send)
	var result: Dictionary = await Account.forgot_password(value("email"))
	if not is_inside_tree():
		return
	set_busy(false, _send)
	if result.ok:
		_show_step(1)
	else:
		show_error(result, _send)


func _reset_password() -> void:
	clear_errors()
	if not value("code").is_valid_int() or value("code").length() != 6:
		field_error("code", "The code is 6 digits.")
		return
	var problem := password_problem(value("new_password"))
	if problem != "":
		field_error("new_password", problem)
		return
	if value("confirm_password") != value("new_password"):
		field_error("confirm_password", "The passwords don't match.")
		return
	set_busy(true, _reset)
	var result: Dictionary = await Account.reset_password(value("email"), value("code"), value("new_password"))
	if not is_inside_tree():
		return
	set_busy(false, _reset)
	if result.ok:
		Game.notice = "Password changed. Log in with your new password."
		Game.go_to(Game.LOGIN)
	else:
		show_error(result, _reset)


func go_back() -> void:
	Game.go_to(Game.LOGIN)
