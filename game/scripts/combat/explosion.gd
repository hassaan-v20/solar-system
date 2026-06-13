class_name Explosion
extends Node3D
## Presentation juice (GDD §20): a short procedural burst — flash light, expanding
## emissive shell, and a particle spray — that frees itself. No art assets, pure
## code. Used for hit sparks (small radius) and kills (large radius).
## Spawn via Explosion.spawn(parent, world_pos, radius, color).

var _radius: float = 1.0
var _color: Color = Color(1.0, 0.6, 0.2)

static func spawn(parent: Node, world_pos: Vector3, radius: float, color: Color) -> void:
	if parent == null:
		return
	var e := Explosion.new()
	e._radius = radius
	e._color = color
	parent.add_child(e)
	e.global_position = world_pos

func _ready() -> void:
	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 6.0 * _radius
	light.omni_range = 14.0 * _radius
	add_child(light)

	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = _radius
	sphere.height = _radius * 2.0
	shell.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = _color
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = 4.0
	shell.material_override = mat
	add_child(shell)

	var particles := GPUParticles3D.new()
	particles.amount = int(12 + 24 * _radius)
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0 * _radius
	pm.initial_velocity_max = 12.0 * _radius
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.2 * _radius
	pm.scale_max = 0.5 * _radius
	pm.color = _color
	particles.process_material = pm
	var spark := SphereMesh.new()
	spark.radius = 0.15
	spark.height = 0.3
	particles.draw_pass_1 = spark
	particles.emitting = true
	add_child(particles)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(light, "light_energy", 0.0, 0.4)
	tw.tween_property(shell, "scale", Vector3.ONE * 2.6, 0.4)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	get_tree().create_timer(0.7).timeout.connect(queue_free)
