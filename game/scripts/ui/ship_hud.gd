class_name ShipHUD
extends CanvasLayer
## Minimal flight HUD (Presentation). Built in code for Milestone 1; it becomes a
## proper .tscn with role-specific panels in later milestones (GDD §19).

@export var ship: ShipController

var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _boost_label: Label

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

	var hint := Label.new()
	hint.text = "W/S thrust   mouse steer   A/D roll   Q/E strafe   Shift boost   Ctrl brake   Esc free mouse   F8 quit"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	root.add_child(hint)

func _make_label(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	return l

func _process(_delta: float) -> void:
	if ship == null or ship.ship_def == null:
		return
	_hull_label.text = "HULL    %d / %d" % [int(ship.current_hull), int(ship.ship_def.hull_max)]
	_shield_label.text = "SHIELD  %d / %d" % [int(ship.current_shield), int(ship.ship_def.shield_max)]
	_speed_label.text = "SPEED   %d m/s" % roundi(ship.get_speed())
	_boost_label.text = "BOOST   %s" % ("ENGAGED" if ship.is_boosting else "ready")
