## Create an account: unique username, email, password (typed twice).
extends FormScreen


func _ready() -> void:
	build("SIGN UP", "An account gives you a profile and a rating from online matches.")
	var username := add_field("username", "Username", false, LineEdit.KEYBOARD_TYPE_DEFAULT, "3–20 letters, numbers or _")
	add_field("email", "Email", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
	add_field("password", "Password", true, LineEdit.KEYBOARD_TYPE_PASSWORD, "At least 8 characters")
	add_field("confirm_password", "Confirm password", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
	add_submit("Create account", _sign_up)
	add_link("Already a member? Log in", func(): Game.go_to(Game.LOGIN))
	MenuStyle.focus_later(username)


func _sign_up() -> void:
	clear_errors()
	var checks := {
		"username": username_problem(value("username")),
		"email": email_problem(value("email")),
		"password": password_problem(value("password")),
		"confirm_password": "" if value("confirm_password") == value("password") else "The passwords don't match.",
	}
	for field_name in checks:
		if checks[field_name] != "":
			field_error(field_name, checks[field_name])
			return
	set_busy(true)
	var result: Dictionary = await Account.signup(value("username"), value("email"), value("password"))
	if not is_inside_tree():
		return
	set_busy(false)
	if result.ok:
		Game.notice = "Welcome to Rann, %s!" % Account.username()
		Game.go_to_main_menu()
	else:
		show_error(result)


func go_back() -> void:
	Game.go_to(Game.LOGIN)
