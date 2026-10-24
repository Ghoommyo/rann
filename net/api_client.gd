## Talks to the Rann server (see server/): JSON over HTTP. Registered as the
## "Api" autoload. Calls that need a login go through Account instead, which
## adds the login token and renews it when it expires.
##
## Every call returns a Dictionary and never fails with an error:
##   {ok, status, data, error, message, field}
## `error` is a stable code ("username_taken", "network", ...), `message` is
## ready to show to the player and `field` names the form field at fault.
##
## 💡 `await Api.send(...)` pauses the calling function until the server
## answers, without freezing the game.
extends Node

const TIMEOUT_SECONDS := 10.0


func send(method: HTTPClient.Method, path: String, body: Variant = null, token := "") -> Dictionary:
	var url := base_url() + path
	var headers := PackedStringArray(["Accept: application/json"])
	var payload := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(body)
	if token != "":
		headers.append("Authorization: Bearer " + token)

	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	if http.request(url, headers, method, payload) != OK:
		http.queue_free()
		return unreachable()
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return unreachable()
	return parse_response(response[1], response[3])


func base_url() -> String:
	return Settings.api_url.strip_edges().trim_suffix("/")


func unreachable() -> Dictionary:
	return failure(0, "network", "Couldn't reach the server at %s. Check Settings → Server." % base_url())


static func failure(status: int, error: String, message: String, field := "") -> Dictionary:
	return {"ok": false, "status": status, "data": {}, "error": error, "message": message, "field": field}


static func parse_response(status: int, bytes: PackedByteArray) -> Dictionary:
	var json := JSON.new()  # (unlike JSON.parse_string, doesn't log an error for non-JSON answers)
	var data: Variant = null
	if json.parse(bytes.get_string_from_utf8()) == OK:
		data = json.data
	if not data is Dictionary:
		data = {}
	if status >= 200 and status < 300:
		return {"ok": true, "status": status, "data": data, "error": "", "message": "", "field": ""}
	if status == 429:
		return failure(status, "rate_limited", "Too many tries. Wait a minute and try again.")
	var field: Variant = data.get("field")
	return failure(status, str(data.get("error", "http_%d" % status)),
		str(data.get("message", "Something went wrong on the server (%d)." % status)),
		field if field is String else "")
