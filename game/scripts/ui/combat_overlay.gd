class_name CombatOverlay
extends Control
## World-aware combat HUD drawing (Presentation). Projects enemies to screen for
## target brackets + health bars, points arrows at off-screen foes, and shows
## crosshair, hitmarkers, and a damage vignette. Makes 3D dogfighting readable.

var camera: Camera3D
var ship: ShipController

var _hit_t: float = 0.0
var _flash_t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.hit_landed.connect(func(t, _at): if t != "enemy": _hit_t = 0.12)
	EventBus.player_hit.connect(func(): _flash_t = 0.45)

func _process(delta: float) -> void:
	_hit_t = maxf(0.0, _hit_t - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	queue_redraw()

func _draw() -> void:
	var vp := size
	var c := vp * 0.5

	# Damage vignette + flash.
	var hull_frac := 1.0
	if ship != null and ship.ship_def != null:
		hull_frac = clampf(ship.current_hull / ship.ship_def.hull_max, 0.0, 1.0)
	var danger := (1.0 - hull_frac) * 0.45 + _flash_t * 1.2
	if danger > 0.01:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.75, 0.05, 0.05, clampf(danger, 0.0, 0.5)))

	# Crosshair: ring + centre dot + four ticks.
	var col := Color(0.7, 0.95, 1.0, 0.9)
	draw_arc(c, 14.0, 0.0, TAU, 40, col, 1.6, true)
	draw_circle(c, 1.8, col)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 19.0, c + d * 27.0, col, 2.0)

	# Hitmarker.
	if _hit_t > 0.0:
		var hc := Color(1.0, 0.55, 0.3, 0.95)
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + s * 7.0, c + s * 14.0, hc, 2.0)

	if camera == null:
		return

	var rect := Rect2(Vector2.ZERO, vp)
	for e in get_tree().get_nodes_in_group("enemy"):
		var e3 := e as Node3D
		if e3 == null:
			continue
		var wp := e3.global_position
		var behind := camera.is_position_behind(wp)
		var sp := camera.unproject_position(wp)
		var is_boss: bool = ("enemy_def" in e3) and e3.enemy_def != null and e3.enemy_def.is_boss

		var ecol := Color(1.0, 0.5, 0.4, 0.95) if is_boss else Color(1.0, 0.7, 0.4, 0.85)
		if not behind and rect.has_point(sp):
			_draw_bracket(sp, is_boss)
			_draw_enemy_health(e3, sp, is_boss)
		else:
			_draw_arrow(c, _edge_dir(sp, c, behind), vp, ecol)

	# Objective markers (station, jump point) in cyan.
	var ocol := Color(0.4, 0.9, 1.0, 0.95)
	for o in get_tree().get_nodes_in_group("objective"):
		var o3 := o as Node3D
		if o3 == null:
			continue
		var wp := o3.global_position
		var behind := camera.is_position_behind(wp)
		var sp := camera.unproject_position(wp)
		if not behind and rect.has_point(sp):
			_draw_diamond(sp, ocol)
		else:
			_draw_arrow(c, _edge_dir(sp, c, behind), vp, ocol)

func _edge_dir(sp: Vector2, c: Vector2, behind: bool) -> Vector2:
	var dir := sp - c
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, -1)
	return dir.normalized()

func _draw_diamond(p: Vector2, col: Color) -> void:
	var r := 9.0
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	for i in 4:
		draw_line(pts[i], pts[(i + 1) % 4], col, 2.0)

func _draw_bracket(p: Vector2, boss: bool) -> void:
	var s := 26.0 if boss else 15.0
	var col := Color(1.0, 0.5, 0.4, 0.95) if boss else Color(1.0, 0.75, 0.4, 0.9)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var o: Vector2 = corner * s
		draw_line(p + o, p + o - Vector2(corner.x, 0) * 8.0, col, 2.0)
		draw_line(p + o, p + o - Vector2(0, corner.y) * 8.0, col, 2.0)

func _draw_enemy_health(e: Node3D, p: Vector2, boss: bool) -> void:
	if not ("current_hull" in e) or not ("enemy_def" in e) or e.enemy_def == null:
		return
	var frac := clampf(e.current_hull / maxf(1.0, e.enemy_def.hull_max), 0.0, 1.0)
	var w := 60.0 if boss else 34.0
	var y := p.y - (34.0 if boss else 22.0)
	draw_rect(Rect2(p.x - w * 0.5, y, w, 4.0), Color(0.1, 0.0, 0.0, 0.8))
	draw_rect(Rect2(p.x - w * 0.5, y, w * frac, 4.0), Color(1.0, 0.35, 0.3, 0.95))

func _draw_arrow(c: Vector2, dir: Vector2, vp: Vector2, col: Color) -> void:
	var m := 70.0
	var t := INF
	if dir.x > 0.001:
		t = minf(t, (vp.x - m - c.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (m - c.x) / dir.x)
	if dir.y > 0.001:
		t = minf(t, (vp.y - m - c.y) / dir.y)
	elif dir.y < -0.001:
		t = minf(t, (m - c.y) / dir.y)
	if t == INF:
		return
	var pos := c + dir * t
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([pos + dir * 12.0, pos - dir * 6.0 + perp * 8.0, pos - dir * 6.0 - perp * 8.0])
	draw_colored_polygon(pts, col)
