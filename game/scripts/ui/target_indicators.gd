class_name TargetIndicators
extends Control
## HUD overlay (Presentation): off-screen direction arrows. Green points toward
## teammates (co-op), red toward enemies. Targets already on-screen are skipped —
## their nameplate / lead pip marks them there. Each arrow clamps to a margin inside
## the viewport edge and points along the bearing to its target.

const MARGIN := 54.0
const ARROW := 15.0
const MAX_ENEMY_ARROWS := 8
const TEAM_COLOR := Color(0.35, 1.0, 0.5)
const ENEMY_COLOR := Color(1.0, 0.32, 0.27)

var camera: Camera3D
var local_ship: Node3D   # don't draw an arrow to yourself

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	# Use the real viewport size — a CanvasLayer child Control's own `size` can stay
	# (0,0), which would silently suppress every arrow. unproject_position projects
	# into this same space.
	var vp := get_viewport_rect().size
	if vp.x < MARGIN * 2.0 + 1.0 or vp.y < MARGIN * 2.0 + 1.0:
		return
	# Teammates: arrow only when off-screen (you can already see them on-screen).
	for p in get_tree().get_nodes_in_group("players"):
		if p == local_ship or not is_instance_valid(p):
			continue
		_indicate(vp, (p as Node3D).global_position, TEAM_COLOR, false)
	# Enemies: a reticle when on-screen, an edge arrow when off-screen.
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if _indicate(vp, (e as Node3D).global_position, ENEMY_COLOR, true):
			n += 1
			if n >= MAX_ENEMY_ARROWS:
				break

## Marks `world`: a reticle if it's on-screen (only when mark_onscreen), else an edge
## arrow pointing toward it. Returns true if it drew anything.
func _indicate(vp: Vector2, world: Vector3, color: Color, mark_onscreen: bool) -> bool:
	var center := vp * 0.5
	var behind := camera.is_position_behind(world)
	var sp := camera.unproject_position(world)
	if not behind and Rect2(Vector2.ZERO, vp).has_point(sp):
		if not mark_onscreen:
			return false
		_reticle(sp, color)
		return true
	if behind:
		sp = center - (sp - center)   # mirror a behind-camera point onto the correct side
	var dir := sp - center
	if dir.length() < 0.001:
		return false
	dir = dir.normalized()
	var half := vp * 0.5 - Vector2(MARGIN, MARGIN)
	var sx: float = INF
	if absf(dir.x) > 0.0001:
		sx = half.x / absf(dir.x)
	var sy: float = INF
	if absf(dir.y) > 0.0001:
		sy = half.y / absf(dir.y)
	var edge := center + dir * minf(sx, sy)
	var ang := dir.angle()
	draw_colored_polygon(PackedVector2Array([
		edge + Vector2(ARROW, 0).rotated(ang),
		edge + Vector2(-ARROW * 0.7, ARROW * 0.7).rotated(ang),
		edge + Vector2(-ARROW * 0.7, -ARROW * 0.7).rotated(ang),
	]), color)
	return true

## A small diamond drawn around an on-screen target.
func _reticle(p: Vector2, color: Color) -> void:
	var r := 13.0
	draw_polyline(PackedVector2Array([
		p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r),
	]), color, 2.0)
