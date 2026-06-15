class_name LocalHealthBar
extends Control
## Bottom-left status bars for the local pilot's own ship: shield (blue), hull
## (green), and the boost reserve (amber; red while locked out / recharging). The
## top-left readout still shows exact numbers — this is the at-a-glance bar.

var ship: ShipController

const LABEL_X := 24.0
const BAR_X := 96.0
const W := 240.0
const H := 15.0
const GAP := 5.0
const BOTTOM := 132.0   # px the top bar sits above the bottom edge (clears the controls hint)
const BG := Color(0.0, 0.0, 0.0, 0.55)
const SHIELD_COL := Color(0.4, 0.7, 1.0)
const HULL_COL := Color(0.4, 1.0, 0.55)
const BOOST_COL := Color(1.0, 0.7, 0.25)
const BOOST_LOCK_COL := Color(1.0, 0.35, 0.2)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if ship == null or not is_instance_valid(ship) or ship.ship_def == null:
		return
	var y := get_viewport_rect().size.y - BOTTOM
	_bar(y, "SHLD", ship.current_shield / maxf(1.0, ship.ship_def.shield_max), SHIELD_COL)
	_bar(y + H + GAP, "HULL", ship.current_hull / maxf(1.0, ship.ship_def.hull_max), HULL_COL)
	var boost_col: Color = BOOST_LOCK_COL if ship.boost_locked else BOOST_COL
	_bar(y + (H + GAP) * 2.0, "BST", ship.boost_energy / maxf(0.01, ship.ship_def.boost_capacity), boost_col)

func _bar(y: float, label: String, frac: float, col: Color) -> void:
	var f := clampf(frac, 0.0, 1.0)
	draw_string(get_theme_default_font(), Vector2(LABEL_X, y + H - 2), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
	var top := Vector2(BAR_X, y)
	draw_rect(Rect2(top, Vector2(W, H)), BG, true)
	draw_rect(Rect2(top, Vector2(W * f, H)), col, true)
	draw_rect(Rect2(top, Vector2(W, H)), Color(1, 1, 1, 0.22), false, 1.0)
