## Log in with a username or email. Also leads to sign-up, forgot password,
## or playing as a guest.
extends FormScreen

var _submit: Button
var _reactivate: Button


func _ready() -> void:
	build("LOG IN", "Log in to earn a rating from online matches.")
	var login := add_field("login", "Username or email", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	add_field("password", "Password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	add_link("Forgot password?", func(): Game.go_to(Game.FORGOT_PASSWORD))
	_submit = add_submit("Log in", _log_in)
	_reactivate = add_button("Reactivate my account", _log_in.bind(true))
	_reactivate.visible = false
	add_link("Not a member? Sign up", func(): Game.go_to(Game.SIGNUP))
	add_link("Continue as guest", _continue_as_guest)
	MenuStyle.focus_later(login)


func _log_in(reactivate := false) -> void:
	clear_errors()
	if value("login") == "":
		field_error("login", "Enter your username or email.")
		return
	if value("password") == "":
		field_error("password", "Enter your password.")
		return
	set_busy(true)
	var result: Dictionary = await Account.login(value("login"), value("password"), reactivate)
	if not is_inside_tree():
		return
	set_busy(false)
	if result.ok:
		Game.notice = "Welcome back, %s!" % Account.username() if not reactivate else "Your account is active again."
		Game.go_to_main_menu()
	elif result.error == "account_deactivated":
		show_status("This account is deactivated. Reactivate it to log in.")
		_reactivate.visible = true
		MenuStyle.focus_later(_reactivate)
	else:
		show_error(result)


func _continue_as_guest() -> void:
	Account.continue_as_guest()
	Game.go_to_main_menu()
