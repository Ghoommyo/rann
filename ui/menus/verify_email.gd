## "Enter the code we emailed you": confirms a new account's email. Shown
## after sign-up, and when someone logs in before confirming. The account
## (Account.pending_login) can be used once the code is right.
extends FormScreen

var _verify: Button


func _ready() -> void:
	if Account.pending_login == "":
		Game.go_to.call_deferred(Game.LOGIN)
		return
	build("CONFIRM YOUR EMAIL", "Enter the 6-digit code we emailed you. It works for 15 minutes; check your spam folder if you can't find it.")
	var code := add_field("code", "Code", false, LineEdit.KEYBOARD_TYPE_NUMBER, "123456")
	code.max_length = 6
	_verify = add_submit("Confirm", _confirm)
	add_link("Resend code", _resend)
	add_link("Back to log in", go_back)
	MenuStyle.focus_later(code)
	if Account.pending_send_code:
		Account.pending_send_code = false
		_resend()


func _confirm() -> void:
	clear_errors()
	if not value("code").is_valid_int() or value("code").length() != 6:
		field_error("code", "The code is 6 digits.")
		return
	set_busy(true, _verify)
	var result: Dictionary = await Account.verify_email(Account.pending_login, value("code"))
	if not is_inside_tree():
		return
	set_busy(false, _verify)
	if result.ok:
		Game.notice = "Welcome to Rann, %s!" % Account.username()
		Game.go_to_main_menu()
	else:
		show_error(result, _verify)


func _resend() -> void:
	clear_errors()
	set_busy(true, _verify)
	var result: Dictionary = await Account.resend_verification(Account.pending_login)
	if not is_inside_tree():
		return
	set_busy(false, _verify)
	if result.ok:
		set_value("code", "")
		show_status("We sent a new code to your email.", MenuStyle.SUCCESS, _verify)
	else:
		show_error(result, _verify)


func go_back() -> void:
	Game.go_to(Game.LOGIN)
