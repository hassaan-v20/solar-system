class_name Fx
extends Node
## Lightweight combat VFX driven by EventBus: impact sparks on hits and a flash +
## burst on kills. Each effect is a short-lived emissive primitive (and a brief
## light for explosions) that tweens out and frees itself.

var world: Node3D

func _ready() -> void:
	EventBus.hit_landed.connect(_on_hit)
	EventBus.enemy_died.connect(_on_boom)

func _on_hit(team: String, at: Vector3) -> void:
	var col := Color(0.6, 0.9, 1.0) if team == "player" else Color(1.0, 0.55, 0.35)
	burst(at, col, 0.8, 0.18, 5.0)

func _on_boom(at: Vector3) -> void:
	burst(at, Color(1.0, 0.62, 0.25), 2.4, 0.5, 6.0)
	flash(at, Color(1.0, 0.6, 0.3), 10.0, 7.0, 0.4)

func burst(at: Vector3, col: Color, size: float, dur: float, energy: float) -> void:
	if world == null:
		return
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 8
	s.rings = 5
	fx.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx.material_override = m
	world.add_child(fx)
	fx.global_position = at
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3.ONE * 3.0, dur)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(fx.queue_free)

func flash(at: Vector3, col: Color, energy: float, rng: float, dur: float) -> void:
	if world == null:
		return
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng * 6.0
	world.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)
