class_name ShipHUD
extends CanvasLayer
## Flight + combat HUD (Presentation). Built in code for the slice; becomes a
## proper .tscn with role-specific panels in later milestones (GDD §19).

@export var ship: ShipController
var weapon: WeaponController

var _hull: Label
var _shield: Label
var _speed: Label
var _boost: Label
var _combat: Label
var _cross: Label
var _heat_bg: ColorRect
var _heat_fill: ColorRect
var _dim: ColorRect
var _dead: Label

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := VBoxContainer.new()
	panel.position = Vector2(28, 24)
	root.add_child(panel)
	_hull = _make_label(panel)
	_shield = _make_label(panel)
	_speed = _make_label(panel)
	_boost = _make_label(panel)

	_combat = Label.new()
	_combat.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_combat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combat.offset_right = -28
	_combat.offset_top = 24
	root.add_child(_combat)

	_cross = Label.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cross.add_theme_font_size_override("font_size", 26)
	_cross.modulate = Color(1, 1, 1, 0.7)
	_cross.text = "+"
	root.add_child(_cross)

	_heat_bg = ColorRect.new()
	_heat_bg.color = Color(0.1, 0.1, 0.14, 0.85)
	_heat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_heat_bg)
	_heat_fill = ColorRect.new()
	_heat_fill.color = Color(0.4, 0.7, 1.0, 0.95)
	_heat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_heat_fill)

	var hint := Label.new()
	hint.text = "W/S thrust   mouse steer   A/D roll   Q/E strafe   Shift boost   Ctrl brake   Space/LMB fire   Esc free mouse   F8 quit"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.45)
	root.add_child(hint)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.3, 0.0, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	_dead = Label.new()
	_dead.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dead.add_theme_font_size_override("font_size", 52)
	_dead.modulate = Color(1.0, 0.5, 0.45)
	_dead.text = "SHIP DESTROYED\nrespawning…"
	_dead.visible = false
	root.add_child(_dead)

func _make_label(parent: Node) -> Label:
	var l := Label.new()
	parent.add_child(l)
	return l

func set_combat(kills: int, enemies: int, score: int, wave: int) -> void:
	if _combat != null:
		_combat.text = "WAVE %d    ENEMIES %d    KILLS %d    SCORE %d" % [wave, enemies, kills, score]

func show_destroyed() -> void:
	_dead.visible = true
	_dim.color = Color(0.3, 0.0, 0.0, 0.35)

func hide_destroyed() -> void:
	_dead.visible = false
	_dim.color = Color(0.3, 0.0, 0.0, 0.0)

func _process(_delta: float) -> void:
	if ship != null and ship.ship_def != null:
		_hull.text = "HULL    %d / %d" % [int(ship.current_hull), int(ship.ship_def.hull_max)]
		_shield.text = "SHIELD  %d / %d" % [int(ship.current_shield), int(ship.ship_def.shield_max)]
		_speed.text = "SPEED   %d m/s" % roundi(ship.get_speed())
		_boost.text = "BOOST   %s" % ("ENGAGED" if ship.is_boosting else "ready")

	# Heat bar, centred near the bottom.
	var vp := get_viewport().get_visible_rect().size
	var w := 320.0
	var x := (vp.x - w) * 0.5
	var y := vp.y - 64.0
	_heat_bg.position = Vector2(x, y)
	_heat_bg.size = Vector2(w, 12)
	if weapon != null:
		var frac := clampf(weapon.heat_fraction(), 0.0, 1.0)
		_heat_fill.position = Vector2(x, y)
		_heat_fill.size = Vector2(w * frac, 12)
		_heat_fill.color = Color(1.0, 0.3, 0.2, 0.95) if weapon.overheated else Color(0.4, 0.7, 1.0, 0.95)
