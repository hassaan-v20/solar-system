class_name ShipHUD
extends CanvasLayer
## Minimal flight HUD (Presentation). Built in code for Milestone 1; it becomes a
## proper .tscn with role-specific panels in later milestones (GDD §19).

@export var ship: ShipController

var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _boost_label: Label
var _heat_label: Label
var _enemies_label: Label
var _objective_label: Label
var _timer_label: Label
var _dock_label: Label
var _status_label: Label

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	root.add_child(panel)
	_hull_label = _make_label(panel)
	_shield_label = _make_label(panel)
	_speed_label = _make_label(panel)
	_boost_label = _make_label(panel)
	_heat_label = _make_label(panel)
	_enemies_label = _make_label(panel)

	# Mission objective banner (top-center).
	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_top = 18
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_objective_label)

	# Meltdown countdown (top-center, under the objective; shown during extraction).
	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_timer_label.offset_top = 46
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.visible = false
	root.add_child(_timer_label)

	# Docking prompt + end-of-mission status (both center; never shown together).
	_dock_label = Label.new()
	_dock_label.text = "PRESS F TO DOCK"
	_dock_label.set_anchors_preset(Control.PRESET_CENTER)
	_dock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_label.modulate = Color(0.5, 0.9, 1.0)
	_dock_label.visible = false
	root.add_child(_dock_label)

	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_CENTER)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.visible = false
	root.add_child(_status_label)

	EventBus.objective_updated.connect(func(t: String) -> void: _objective_label.text = t)
	EventBus.docking_available.connect(func(b: bool) -> void: _dock_label.visible = b)
	EventBus.extraction_timer_changed.connect(_on_extraction_timer)
	EventBus.mission_state_changed.connect(_on_mission_state)

	var hint := Label.new()
	hint.text = "W/S thrust   mouse steer   A/D roll   Q/E strafe   LMB fire   Shift boost   Ctrl brake   Esc free mouse   F11 fullscreen   F8 quit"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	root.add_child(hint)

func _make_label(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	return l

func _on_extraction_timer(seconds_left: float) -> void:
	_timer_label.visible = true
	var s := int(ceil(seconds_left))
	_timer_label.text = "MELTDOWN  %d:%02d" % [s / 60, s % 60]
	# Flash to red as the deadline closes in.
	_timer_label.modulate = Color(1.0, 0.3, 0.25) if seconds_left < 15.0 else Color(1.0, 0.85, 0.3)

func _on_mission_state(state: String) -> void:
	if state == "success":
		_timer_label.visible = false
		_dock_label.visible = false
		_status_label.text = "MISSION COMPLETE"
		_status_label.modulate = Color(0.4, 1.0, 0.5)
		_status_label.visible = true
	elif state == "failed":
		_timer_label.visible = false
		_dock_label.visible = false
		_status_label.text = "MISSION FAILED — F8 to quit"
		_status_label.modulate = Color(1.0, 0.3, 0.25)
		_status_label.visible = true

func _process(_delta: float) -> void:
	if ship == null or ship.ship_def == null:
		return
	_hull_label.text = "HULL    %d / %d" % [int(ship.current_hull), int(ship.ship_def.hull_max)]
	_shield_label.text = "SHIELD  %d / %d" % [int(ship.current_shield), int(ship.ship_def.shield_max)]
	_speed_label.text = "SPEED   %d m/s" % roundi(ship.get_speed())
	_boost_label.text = "BOOST   %s" % ("ENGAGED" if ship.is_boosting else "ready")
	if ship.weapon != null and ship.weapon.weapon_def != null:
		_heat_label.text = "HEAT    %d%%" % int(100.0 * ship.weapon.heat / ship.weapon.weapon_def.max_heat)
	_enemies_label.text = "DRONES  %d" % get_tree().get_nodes_in_group("enemies").size()
