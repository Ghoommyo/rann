## The logged-in player (or a guest), and every server call that needs a
## login. Registered as the "Account" autoload.
##
## 💡 Logging in gives two tokens: a short-lived access token sent with each
## request, and a long-lived refresh token that buys a new access token when
## it runs out. Only the refresh token is saved (user://session.cfg), so the
## player stays logged in between launches without the password being stored.
extends Node

## Emitted when the player logs in or out, or their profile changes.
signal changed
signal _refreshed(result: Dictionary)

const PATH := "user://session.cfg"

## The player's profile from the server: username, email, bio, rating,
## rating_deviation, rank, games_played, wins, losses, draws, member_since.
## Empty for a guest.
var user: Dictionary = {}
## Set once the player picks "Continue as guest", so later launches skip the
## login screen.
var guest := false

var _access_token := ""
var _access_expires_ms := 0
var _refresh_token := ""
var _refreshing := false
var _path := PATH


func _ready() -> void:
	# --session=NAME keeps a separate login, e.g. to test two accounts in two
	# game windows on one computer.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--session="):
			_path = "user://session_%s.cfg" % arg.trim_prefix("--session=").validate_filename()
	load_session(_path)


func is_logged_in() -> bool:
	return not user.is_empty()


func username() -> String:
	return str(user.get("username", ""))


## Whether a login from an earlier launch can be restored.
func has_saved_session() -> bool:
	return _refresh_token != ""


## `path` lets tests use their own file.
func load_session(path := PATH) -> void:
	_path = path
	_access_token = ""
	_refresh_token = ""
	guest = false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	_refresh_token = str(cfg.get_value("session", "refresh_token", ""))
	guest = bool(cfg.get_value("session", "guest", false))


func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", _refresh_token)
	cfg.set_value("session", "guest", guest)
	cfg.save(_path)


## Logs back in with the saved session (at startup).
func restore() -> Dictionary:
	var result := await _refresh()
	if result.ok:
		result = await refresh_profile()
	return result


func signup(new_username: String, email: String, password: String) -> Dictionary:
	var result := await Api.send(HTTPClient.METHOD_POST, "/auth/signup",
		{"username": new_username, "email": email, "password": password})
	if result.ok:
		_logged_in(result.data)
	return result


## `login` is a username or an email. A deactivated account answers with the
## error "account_deactivated" unless `reactivate` is set.
func login(login_name: String, password: String, reactivate := false) -> Dictionary:
	var result := await Api.send(HTTPClient.METHOD_POST, "/auth/login",
		{"login": login_name, "password": password, "reactivate": reactivate})
	if result.ok:
		_logged_in(result.data)
	return result


func logout() -> void:
	if _refresh_token != "":
		Api.send(HTTPClient.METHOD_POST, "/auth/logout", {"refresh_token": _refresh_token})
	_forget()


func continue_as_guest() -> void:
	guest = true
	_save_session()


func forgot_password(email: String) -> Dictionary:
	return await Api.send(HTTPClient.METHOD_POST, "/auth/forgot-password", {"email": email})


func reset_password(email: String, code: String, new_password: String) -> Dictionary:
	return await Api.send(HTTPClient.METHOD_POST, "/auth/reset-password",
		{"email": email, "code": code, "new_password": new_password})


func refresh_profile() -> Dictionary:
	return _take_profile(await call_api(HTTPClient.METHOD_GET, "/me"))


func update_bio(bio: String) -> Dictionary:
	return _take_profile(await call_api(HTTPClient.METHOD_PATCH, "/me", {"bio": bio}))


func change_username(new_name: String) -> Dictionary:
	return _take_profile(await call_api(HTTPClient.METHOD_PATCH, "/me/username", {"username": new_name}))


func change_email(email: String, password: String) -> Dictionary:
	return _take_profile(await call_api(HTTPClient.METHOD_PATCH, "/me/email", {"email": email, "password": password}))


## Logs out every other device; this one gets a new session.
func change_password(current_password: String, new_password: String) -> Dictionary:
	var result := await call_api(HTTPClient.METHOD_PATCH, "/me/password",
		{"current_password": current_password, "new_password": new_password})
	if result.ok:
		_take_tokens(result.data)
	return result


## Hides the profile and logs out. Logging in again reactivates it.
func deactivate(password: String) -> Dictionary:
	var result := await call_api(HTTPClient.METHOD_POST, "/me/deactivate", {"password": password})
	if result.ok:
		_forget()
	return result


## A server call as the logged-in player. Renews the access token first if it
## has run out (or the server says so) and retries once.
func call_api(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	if _refresh_token == "":
		return Api.failure(401, "unauthorized", "Please log in.")
	if _access_token == "" or Time.get_ticks_msec() >= _access_expires_ms:
		var renewed := await _refresh()
		if not renewed.ok:
			return renewed
	var result := await Api.send(method, path, body, _access_token)
	if result.status == 401:
		var renewed := await _refresh()
		if not renewed.ok:
			return renewed
		result = await Api.send(method, path, body, _access_token)
	return result


## Swaps the refresh token for a new pair. Only one swap runs at a time: the
## old refresh token stops working once used, so a second swap would fail.
func _refresh() -> Dictionary:
	if _refreshing:
		return await _refreshed
	if _refresh_token == "":
		return Api.failure(401, "unauthorized", "Please log in.")
	_refreshing = true
	var result := await Api.send(HTTPClient.METHOD_POST, "/auth/refresh", {"refresh_token": _refresh_token})
	if result.ok:
		_take_tokens(result.data)
	elif result.status == 401:
		_forget()  # expired, logged out elsewhere, or the account was deactivated
	_refreshing = false
	_refreshed.emit(result)
	return result


func _logged_in(data: Dictionary) -> void:
	guest = false
	_take_tokens(data)
	user = data.get("user", {})
	changed.emit()


func _take_tokens(data: Dictionary) -> void:
	_access_token = str(data.get("access_token", ""))
	_refresh_token = str(data.get("refresh_token", _refresh_token))
	# Renew a little early so a request never arrives with a just-expired token.
	_access_expires_ms = Time.get_ticks_msec() + int(maxf(float(data.get("expires_in", 900)) - 30.0, 0.0) * 1000.0)
	_save_session()


func _take_profile(result: Dictionary) -> Dictionary:
	if result.ok:
		user = result.data
		changed.emit()
	return result


func _forget() -> void:
	var was_logged_in := is_logged_in()
	user = {}
	_access_token = ""
	_refresh_token = ""
	_save_session()
	if was_logged_in:
		changed.emit()
