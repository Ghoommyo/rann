## Accounts on the game side: the saved session, reading server answers, the
## form checks, and that every account screen opens.
extends GutTest

const PATH := "user://session_test.cfg"


func after_each():
	Account.load_session()  # back to the real file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_session_round_trip():
	Account.load_session(PATH)
	assert_false(Account.has_saved_session(), "no file yet: not logged in")
	Account._take_tokens({"access_token": "a", "refresh_token": "r-123", "expires_in": 900})
	Account.load_session(PATH)
	assert_true(Account.has_saved_session())
	assert_eq(Account._refresh_token, "r-123")
	assert_eq(Account._access_token, "", "the access token is never saved")


func test_guest_choice_is_remembered_and_cleared_by_logging_in():
	Account.load_session(PATH)
	Account.continue_as_guest()
	Account.load_session(PATH)
	assert_true(Account.guest)
	Account._logged_in({"access_token": "a", "refresh_token": "r", "user": {"username": "arjun"}})
	assert_eq(Account.username(), "arjun")
	Account.load_session(PATH)
	assert_false(Account.guest)
	Account._forget()
	assert_false(Account.is_logged_in())
	Account.load_session(PATH)
	assert_false(Account.has_saved_session())


func test_parse_success():
	var r := Api.parse_response(200, '{"username":"arjun"}'.to_utf8_buffer())
	assert_true(r.ok)
	assert_eq(r.data.username, "arjun")


func test_parse_error_with_field():
	var r := Api.parse_response(409, '{"error":"username_taken","message":"That username is taken.","field":"username"}'.to_utf8_buffer())
	assert_false(r.ok)
	assert_eq(r.error, "username_taken")
	assert_eq(r.message, "That username is taken.")
	assert_eq(r.field, "username")


func test_parse_odd_answers():
	assert_eq(Api.parse_response(500, PackedByteArray()).field, "")
	assert_eq(Api.parse_response(502, "<html>".to_utf8_buffer()).error, "http_502")
	assert_eq(Api.parse_response(429, '{"error":"Too Many Requests"}'.to_utf8_buffer()).error, "rate_limited")


func test_form_checks_match_the_server_rules():
	assert_eq(FormScreen.username_problem("arjun_99"), "")
	for bad in ["ab", "has space", "x".repeat(21), "naïve"]:
		assert_ne(FormScreen.username_problem(bad), "", bad)
	assert_eq(FormScreen.email_problem("a@b.co"), "")
	assert_ne(FormScreen.email_problem("a@b"), "")
	assert_eq(FormScreen.password_problem("12345678"), "")
	assert_ne(FormScreen.password_problem("1234567"), "")


func test_account_screens_open():
	Account.load_session(PATH)
	Account._logged_in({"access_token": "a", "refresh_token": "r", "user": {"username": "arjun", "rating": 1500, "rating_deviation": 350, "rank": null}})
	Account._access_expires_ms = 0
	for scene in [Game.LOGIN, Game.SIGNUP, Game.FORGOT_PASSWORD, Game.PROFILE, Game.ACCOUNT_SETTINGS, Game.MAIN_MENU]:
		var screen: Control = load(scene).instantiate()
		add_child_autofree(screen)
		assert_gt(screen.get_child_count(), 1, scene)
	Account._forget()
