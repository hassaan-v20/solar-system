extends Control
## Station hub (M4): between raids you spend credits on ship upgrades, pick a
## contract, and launch. Shows the last raid's result.

var _credits_lbl: Label
var _contract_btns: Array = []
var _up_rows: Dictionary = {}     # key -> {level, buy}
var _launch: Button

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.07)
	add_child(bg)

	var title := Label.new()
	title.text = "STATION HUB"
	title.position = Vector2(40, 28)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	add_child(title)

	_credits_lbl = Label.new()
	_credits_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_credits_lbl.offset_left = -360
	_credits_lbl.offset_top = 34
	_credits_lbl.offset_right = -40
	_credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credits_lbl.add_theme_font_size_override("font_size", 26)
	_credits_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	add_child(_credits_lbl)

	if not GameState.last_result.is_empty():
		var r := GameState.last_result
		var res := Label.new()
		res.position = Vector2(40, 84)
		res.add_theme_font_size_override("font_size", 22)
		var ok: bool = r.success
		res.text = "Last raid — %s:  %s   +%d cr" % [r.name, ("EXTRACTED" if ok else "LOST"), r.reward]
		res.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.45))
		add_child(res)
		GameState.clear_result()

	_build_contracts()
	_build_upgrades()

	_launch = Button.new()
	_launch.text = "LAUNCH RAID"
	_launch.custom_minimum_size = Vector2(360, 56)
	_launch.add_theme_font_size_override("font_size", 26)
	_launch.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_launch.offset_left = -180
	_launch.offset_top = -90
	_launch.offset_right = 180
	_launch.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/raid/ghost_station_raid.tscn"))
	add_child(_launch)

	var back := Button.new()
	back.text = "Title"
	back.position = Vector2(40, 0)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 40
	back.offset_top = -70
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	add_child(back)

	_refresh()

func _build_contracts() -> void:
	var head := Label.new()
	head.text = "CONTRACTS"
	head.position = Vector2(40, 140)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(head)

	var y := 184
	for path in GameState.MISSIONS:
		var def = load(path)
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(520, 46)
		b.position = Vector2(40, y)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  %s        reward %d cr" % [def.display_name, def.reward]
		b.pressed.connect(_on_contract.bind(path))
		add_child(b)
		_contract_btns.append({"btn": b, "path": path})
		y += 54

func _on_contract(path: String) -> void:
	GameState.selected_mission = path
	_refresh()

func _build_upgrades() -> void:
	var head := Label.new()
	head.text = "UPGRADES"
	head.position = Vector2(640, 140)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	add_child(head)

	var y := 184
	for key in GameState.UPGRADES:
		var name_lbl := Label.new()
		name_lbl.position = Vector2(640, y + 8)
		name_lbl.add_theme_font_size_override("font_size", 18)
		add_child(name_lbl)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150, 40)
		buy.position = Vector2(900, y)
		buy.pressed.connect(_on_buy.bind(key))
		add_child(buy)
		_up_rows[key] = {"name": name_lbl, "buy": buy}
		y += 52

func _on_buy(key: String) -> void:
	GameState.buy(key)
	_refresh()

func _refresh() -> void:
	_credits_lbl.text = "CREDITS  %d" % GameState.credits
	for entry in _contract_btns:
		entry.btn.button_pressed = (entry.path == GameState.selected_mission)
	for key in _up_rows:
		var row = _up_rows[key]
		row.name.text = "%s   Lv %d" % [GameState.UPGRADES[key].name, GameState.upgrades[key]]
		var c := GameState.cost(key)
		row.buy.text = "Buy  %d" % c
		row.buy.disabled = GameState.credits < c
