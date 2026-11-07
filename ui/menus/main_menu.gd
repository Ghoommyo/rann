## The title screen.
## Buttons work with mouse, touch, keyboard (arrows + Enter) and gamepad.
## The top-right menu has the account options (profile, account settings,
## log in/out).
extends Control

enum AccountItem { PROFILE, ACCOUNT_SETTINGS, LOG_OUT, LOG_IN, SIGN_UP }

var _account_button: MenuButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuStyle.background())
	# The emblem, large, to the left of the buttons.
	var art := MenuStyle.emblem(440)
	art.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	art.grow_vertical = Control.GROW_DIRECTION_BOTH
	art.offset_left = 10
	art.offset_right = 450
	art.offset_top = -220
	art.offset_bottom = 220
	art.modulate.a = 0.9
	add_child(art)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(column)

	var title := MenuStyle.label("RANN", 110, MenuStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	# Browsers have no system fonts for Godot to fall back on for Devanagari.
	var subtitle := MenuStyle.label("the battlefield" if OS.has_feature("web") else "रण · the battlefield", 22)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(Control.new())  # spacer

	var vs_cpu := MenuStyle.with_icon(MenuStyle.button("Versus CPU", func(): Game.go_to_character_select(Game.Mode.VERSUS_CPU)), "versus_cpu")
	column.add_child(vs_cpu)
	column.add_child(MenuStyle.with_icon(MenuStyle.button("Local Versus", func(): Game.go_to_character_select(Game.Mode.LOCAL_VERSUS)), "local_versus"))
	column.add_child(MenuStyle.with_icon(MenuStyle.button("Training", func(): Game.go_to_character_select(Game.Mode.TRAINING)), "training"))
	var online := MenuStyle.with_icon(MenuStyle.button("Online", func(): Game.go_to_character_select(Game.Mode.ONLINE)), "online")
	column.add_child(online)
	if OS.has_feature("web"):
		# Browsers can't open the direct (UDP) connections online play uses.
		online.disabled = true
		online.text = "Online · coming to the browser soon"
	column.add_child(MenuStyle.with_icon(MenuStyle.button("Settings", func(): Game.go_to(Game.SETTINGS)), "settings"))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		column.add_child(MenuStyle.with_icon(MenuStyle.button("Quit", func(): get_tree().quit()), "logout"))

	_add_account_menu()
	if Game.notice != "":
		var notice := MenuStyle.label(Game.notice, 20, MenuStyle.SUCCESS)
		notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
		notice.grow_vertical = Control.GROW_DIRECTION_BEGIN
		notice.offset_bottom = -20
		add_child(notice)
		Game.notice = ""
	MenuStyle.focus_later(vs_cpu)


func _add_account_menu() -> void:
	_account_button = MenuButton.new()
	MenuStyle.style_button(_account_button)
	_account_button.flat = false
	_account_button.icon = MenuStyle.icon("menu")
	_account_button.add_theme_constant_override("icon_max_width", 30)
	_account_button.custom_minimum_size = Vector2(0, 56)
	_account_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_account_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_account_button.offset_left = -24
	_account_button.offset_right = -24
	_account_button.offset_top = 20
	add_child(_account_button)

	var popup := _account_button.get_popup()
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_constant_override("v_separation", 18)
	popup.add_theme_constant_override("item_start_padding", 16)
	popup.add_theme_constant_override("item_end_padding", 24)
	popup.add_theme_constant_override("icon_max_width", 32)
	popup.add_theme_constant_override("h_separation", 14)
	popup.id_pressed.connect(_on_account_item)
	Account.changed.connect(_update_account_menu)
	_update_account_menu()


func _update_account_menu() -> void:
	var popup := _account_button.get_popup()
	popup.clear()
	if Account.is_logged_in():
		_account_button.text = "%s · %d" % [Account.username(), int(Account.user.get("rating", 0))]
		popup.add_icon_item(MenuStyle.icon("profile"), "Profile", AccountItem.PROFILE)
		popup.add_icon_item(MenuStyle.icon("settings"), "Account settings", AccountItem.ACCOUNT_SETTINGS)
		popup.add_separator()
		popup.add_icon_item(MenuStyle.icon("logout"), "Log out", AccountItem.LOG_OUT)
	else:
		_account_button.text = "Guest"
		popup.add_icon_item(MenuStyle.icon("profile"), "Log in", AccountItem.LOG_IN)
		popup.add_icon_item(MenuStyle.icon("leaderboard"), "Sign up", AccountItem.SIGN_UP)


func _on_account_item(id: int) -> void:
	match id:
		AccountItem.PROFILE: Game.go_to(Game.PROFILE)
		AccountItem.ACCOUNT_SETTINGS: Game.go_to(Game.ACCOUNT_SETTINGS)
		AccountItem.LOG_IN: Game.go_to(Game.LOGIN)
		AccountItem.SIGN_UP: Game.go_to(Game.SIGNUP)
		AccountItem.LOG_OUT:
			Account.logout()
			Game.go_to(Game.LOGIN)
