extends Control
## Kestrel Station hub (GDD §17). Presentation: shows credits, ship condition +
## repair, the Mission Board (launch Ghost Station), and the upgrade shop. Built
## in code, consistent with the rest of the slice. Reads/writes PlayerProfile.

const RAID_SCENE := "res://scenes/raid/ghost_station_raid.tscn"

var _credits_label: Label
var _hull_label: Label
var _repair_button: Button
var _launch_button: Button
var _hint_label: Label
var _upgrade_rows: Array = []   # [{id, cost, button}]
var _current_device := MenuNav.DEVICE_NONE

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuNav.enable_gamepad_ui()
	_build_ui()
	EventBus.profile_changed.connect(_refresh)
	_refresh()
	# Give the gamepad/keyboard a focused starting point, and show the matching guide.
	_launch_button.grab_focus.call_deferred()
	_current_device = MenuNav.DEVICE_GAMEPAD if MenuNav.gamepad_connected() else MenuNav.DEVICE_KBM
	_update_hint()

func _input(event: InputEvent) -> void:
	var d := MenuNav.device_of(event)
	if d != MenuNav.DEVICE_NONE and d != _current_device:
		_current_device = d
		_update_hint()

func _update_hint() -> void:
	_hint_label.text = MenuNav.hint_text(_current_device)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.position = Vector2(60, 40)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "KESTREL STATION"
	root.add_child(title)

	_credits_label = Label.new()
	root.add_child(_credits_label)
	_hull_label = Label.new()
	root.add_child(_hull_label)

	_repair_button = Button.new()
	_repair_button.pressed.connect(_on_repair)
	root.add_child(_repair_button)

	root.add_child(HSeparator.new())
	var board := Label.new()
	board.text = "MISSION BOARD"
	root.add_child(board)
	_launch_button = Button.new()
	_launch_button.text = "▶  Launch: Ghost Station"
	_launch_button.pressed.connect(_on_launch)
	root.add_child(_launch_button)

	root.add_child(HSeparator.new())
	var shop := Label.new()
	shop.text = "UPGRADES  (bought once, persist between runs)"
	root.add_child(shop)
	for def in UpgradeSystem.all_upgrades():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.text = "%s — %s  (%d cr)" % [def.display_name, def.description, def.cost]
		info.custom_minimum_size = Vector2(440, 0)
		row.add_child(info)
		var buy := Button.new()
		buy.pressed.connect(_on_buy.bind(def.upgrade_id, def.cost))
		row.add_child(buy)
		root.add_child(row)
		_upgrade_rows.append({"id": def.upgrade_id, "cost": def.cost, "button": buy})

	root.add_child(HSeparator.new())
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	root.add_child(quit)

	# Device-aware navigation guide, pinned to the bottom.
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -34
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.modulate = Color(1, 1, 1, 0.55)
	add_child(_hint_label)

func _refresh() -> void:
	_credits_label.text = "Credits: %d" % PlayerProfile.credits
	_hull_label.text = "Ship hull: %d%%" % int(round(PlayerProfile.ship_hull_pct * 100.0))

	var rcost := RewardCalculator.repair_cost(PlayerProfile.ship_hull_pct)
	if rcost <= 0:
		_repair_button.text = "Hull OK"
		_repair_button.disabled = true
	else:
		_repair_button.disabled = false
		var tail := "" if PlayerProfile.can_afford(rcost) else "  (free basic — low credits)"
		_repair_button.text = "Repair hull — %d cr%s" % [rcost, tail]

	for row in _upgrade_rows:
		var btn: Button = row["button"]
		if PlayerProfile.has_upgrade(row["id"]):
			btn.text = "OWNED"
			btn.disabled = true
		else:
			btn.text = "Buy"
			btn.disabled = not PlayerProfile.can_afford(row["cost"])

func _on_launch() -> void:
	get_tree().change_scene_to_file(RAID_SCENE)

func _on_buy(id: String, cost: int) -> void:
	PlayerProfile.buy_upgrade(id, cost)   # UI refreshes via EventBus.profile_changed

func _on_repair() -> void:
	PlayerProfile.repair(RewardCalculator.repair_cost(PlayerProfile.ship_hull_pct))
