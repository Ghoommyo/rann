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

	var vs_cpu := MenuStyle.button("Versus CPU", func(): Game.go_to_character_select(Game.Mode.VERSUS_CPU))
	column.add_child(vs_cpu)
	column.add_child(MenuStyle.button("Local Versus", func(): Game.go_to_character_select(Game.Mode.LOCAL_VERSUS)))
	column.add_child(MenuStyle.button("Training", func(): Game.go_to_character_select(Game.Mode.TRAINING)))
	var online := MenuStyle.button("Online", func(): Game.go_to_character_select(Game.Mode.ONLINE))
	column.add_child(online)
	if OS.has_feature("web"):
		# Browsers can't open the direct (UDP) connections online play uses.
		online.disabled = true
		online.text = "Online · coming to the browser soon"
	column.add_child(MenuStyle.button("Settings", func(): Game.go_to(Game.SETTINGS)))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		column.add_child(MenuStyle.button("Quit", func(): get_tree().quit()))

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
	_account_button.icon = MenuStyle.menu_icon()
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
	popup.id_pressed.connect(_on_account_item)
	Account.changed.connect(_update_account_menu)
	_update_account_menu()


func _update_account_menu() -> void:
	var popup := _account_button.get_popup()
	popup.clear()
	if Account.is_logged_in():
		_account_button.text = "%s · %d" % [Account.username(), int(Account.user.get("rating", 0))]
		popup.add_item("Profile", AccountItem.PROFILE)
		popup.add_item("Account settings", AccountItem.ACCOUNT_SETTINGS)
		popup.add_separator()
		popup.add_item("Log out", AccountItem.LOG_OUT)
	else:
		_account_button.text = "Guest"
		popup.add_item("Log in", AccountItem.LOG_IN)
		popup.add_item("Sign up", AccountItem.SIGN_UP)


func _on_account_item(id: int) -> void:
	match id:
		AccountItem.PROFILE: Game.go_to(Game.PROFILE)
		AccountItem.ACCOUNT_SETTINGS: Game.go_to(Game.ACCOUNT_SETTINGS)
		AccountItem.LOG_IN: Game.go_to(Game.LOGIN)
		AccountItem.SIGN_UP: Game.go_to(Game.SIGNUP)
		AccountItem.LOG_OUT:
			Account.logout()
			Game.go_to(Game.LOGIN)
