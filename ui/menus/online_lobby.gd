## Online lobby: host a match or join one by IP address.
##
## The host's screen shows their local IP addresses. The other player types one
## of them in (same Wi-Fi), or the host's public IP if the host forwarded
## UDP port 7777 on their router.
extends Control

var _status: Label
var _ip_field: LineEdit
var _delay_buttons: Array[Button] = []
var _host_button: Button
var _join_button: Button
var _delay := 2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())
	_delay = Game.cli.delay

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 60
	column.offset_right = -60
	column.offset_top = 30
	column.offset_bottom = -30
	column.add_theme_constant_override("separation", 16)
	add_child(column)

	column.add_child(MenuStyle.label("ONLINE", 22, MenuStyle.ACCENT))
	var me := CharacterRegistry.get_def(Game.p1_id)
	column.add_child(MenuStyle.label("You play: %s" % (me.display_name if me else Game.p1_id), 34))

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 16)
	_host_button = MenuStyle.button("Host a match", _host, 280)
	host_row.add_child(_host_button)
	var ips := MenuStyle.label("Your address: %s   (port %d)" % [", ".join(_local_ips()), EnetTransport.DEFAULT_PORT], 18)
	host_row.add_child(ips)
	column.add_child(host_row)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 16)
	_ip_field = LineEdit.new()
	_ip_field.placeholder_text = "Host's IP address, e.g. 192.168.1.20"
	_ip_field.text = Game.cli.join if Game.cli.join != "" else "127.0.0.1"
	_ip_field.custom_minimum_size = Vector2(420, 56)
	_ip_field.add_theme_font_size_override("font_size", 22)
	join_row.add_child(_ip_field)
	_join_button = MenuStyle.button("Join", _join, 160)
	join_row.add_child(_join_button)
	column.add_child(join_row)

	var delay_row := HBoxContainer.new()
	delay_row.add_theme_constant_override("separation", 10)
	delay_row.add_child(MenuStyle.label("Input delay (host decides):", 20))
	for d in 4:
		var b := MenuStyle.button("%d" % d, func(): _set_delay(d), 70)
		delay_row.add_child(b)
		_delay_buttons.append(b)
	column.add_child(delay_row)
	var hint := MenuStyle.label("💡 2 frames hides most lag. 0 feels sharpest on a fast connection but rolls back more.", 16)
	column.add_child(hint)

	_status = MenuStyle.label("", 24, MenuStyle.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var back := MenuStyle.button("Back", _back, 160)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # don't stretch across the column
	column.add_child(back)
	_set_delay(_delay)
	MenuStyle.focus_later(_host_button)

	# Command-line shortcuts (see Game.cli).
	if Game.cli.host:
		_host.call_deferred()
	elif Game.cli.join != "":
		_join.call_deferred()


func _process(_delta: float) -> void:
	if Game.online == null:
		return
	Game.online.update()
	_status.text = Game.online.status_text()
	var busy := Game.online.status != OnlineConnection.Status.FAILED
	_host_button.disabled = busy
	_join_button.disabled = busy
	if Game.online.status == OnlineConnection.Status.READY:
		Game.p1_id = Game.online.p1_id
		Game.p2_id = Game.online.p2_id
		Game.start_fight()
		set_process(false)


func _host() -> void:
	_new_connection().host(Game.p1_id, _delay)


func _join() -> void:
	_new_connection().join(_ip_field.text, Game.p1_id)


func _new_connection() -> OnlineConnection:
	Game.close_online()
	Game.online = OnlineConnection.new()
	Game.online.transport.lag_ms = Game.cli.lag
	return Game.online


func _set_delay(d: int) -> void:
	_delay = d
	for i in _delay_buttons.size():
		_delay_buttons[i].modulate = Color.WHITE if i == d else Color(1, 1, 1, 0.45)


func _back() -> void:
	Game.go_to_character_select(Game.Mode.ONLINE)


## IPv4 addresses on this machine that another device could reach.
static func _local_ips() -> PackedStringArray:
	var result := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			result.append(ip)
	if result.is_empty():
		result.append("127.0.0.1")
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
