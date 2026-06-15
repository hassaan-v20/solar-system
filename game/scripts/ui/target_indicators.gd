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
	# Need room for the edge inset (and a sane viewport) before any of the rect math.
	if size.x < MARGIN * 2.0 + 1.0 or size.y < MARGIN * 2.0 + 1.0:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p == local_ship or not is_instance_valid(p):
			continue
		_arrow_to((p as Node3D).global_position, TEAM_COLOR)
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if _arrow_to((e as Node3D).global_position, ENEMY_COLOR):
			n += 1
			if n >= MAX_ENEMY_ARROWS:
				break

## Draws an edge pointer toward `world` if it is off-screen; returns true if it drew.
func _arrow_to(world: Vector3, color: Color) -> bool:
	var center := size * 0.5
	var behind := camera.is_position_behind(world)
	var sp := camera.unproject_position(world)
	if behind:
		sp = center - (sp - center)   # mirror a behind-camera point onto the correct side
	var inset := Rect2(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN) * 2.0)
	if not behind and inset.has_point(sp):
		return false   # on-screen — no edge arrow needed
	var dir := sp - center
	if dir.length() < 0.001:
		return false
	dir = dir.normalized()
	var half := size * 0.5 - Vector2(MARGIN, MARGIN)
	var sx: float = INF
	if absf(dir.x) > 0.0001:
		sx = half.x / absf(dir.x)
	var sy: float = INF
	if absf(dir.y) > 0.0001:
		sy = half.y / absf(dir.y)
	var edge := center + dir * minf(sx, sy)
	var ang := dir.angle()
	var pts := PackedVector2Array([
		edge + Vector2(ARROW, 0).rotated(ang),
		edge + Vector2(-ARROW * 0.7, ARROW * 0.7).rotated(ang),
		edge + Vector2(-ARROW * 0.7, -ARROW * 0.7).rotated(ang),
	])
	draw_colored_polygon(pts, color)
	return true
