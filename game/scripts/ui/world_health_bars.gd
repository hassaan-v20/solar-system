class_name WorldHealthBars
extends Control
## HUD overlay (Presentation): small floating bars over on-screen entities — a red
## hull bar on each drone, and a blue shield + green hull pair on each teammate ship.
## Your own ship is skipped (the readout panel already shows it). Bars track each
## entity's projected screen position every frame; off-screen / behind-camera ones
## are dropped (the TargetIndicators arrows cover those).

const W := 46.0
const H := 5.0
const GAP := 2.0
const Y_OFF := 26.0
const BG := Color(0.0, 0.0, 0.0, 0.55)
const HULL_COL := Color(0.4, 1.0, 0.55)
const SHIELD_COL := Color(0.4, 0.7, 1.0)
const DRONE_COL := Color(1.0, 0.35, 0.25)

var camera: Camera3D
var local_ship: Node3D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if camera == null or not is_instance_valid(camera):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("health_fraction"):
			continue
		var frac := float(e.call("health_fraction"))
		_bars((e as Node3D).global_position, PackedFloat32Array([frac]), PackedColorArray([DRONE_COL]))
	for p in get_tree().get_nodes_in_group("players"):
		if p == local_ship or not is_instance_valid(p):
			continue
		var s := p as ShipController
		if s.ship_def == null:
			continue
		var shield_f := s.current_shield / maxf(1.0, s.ship_def.shield_max)
		var hull_f := s.current_hull / maxf(1.0, s.ship_def.hull_max)
		_bars(s.global_position, PackedFloat32Array([shield_f, hull_f]), PackedColorArray([SHIELD_COL, HULL_COL]))

## Draw a stack of bars centered above `world`'s screen position (skip if off-screen).
func _bars(world: Vector3, fracs: PackedFloat32Array, cols: PackedColorArray) -> void:
	if camera.is_position_behind(world):
		return
	var sp := camera.unproject_position(world)
	# Real viewport size — a CanvasLayer child Control's own `size` can be (0,0).
	if not Rect2(Vector2.ZERO, get_viewport_rect().size).has_point(sp):
		return
	var top := sp + Vector2(-W * 0.5, -Y_OFF)
	for i in fracs.size():
		var f := clampf(fracs[i], 0.0, 1.0)
		draw_rect(Rect2(top, Vector2(W, H)), BG, true)
		draw_rect(Rect2(top, Vector2(W * f, H)), cols[i], true)
		top.y += H + GAP
