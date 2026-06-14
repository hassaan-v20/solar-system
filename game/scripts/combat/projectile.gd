class_name Projectile
extends Area3D
## Simulation: a fired energy bolt. Travels straight along its own -Z, damages the
## first body whose layer is in its target mask, then despawns. Whoever fires it
## calls setup() — friend/foe is enforced purely by collision masks (see main.gd
## layer constants), so there is no owner tracking and no friendly fire.

var damage: float = 10.0
var speed: float = 160.0
var lifetime: float = 4.0
# Newtonian gunnery: a bolt inherits the shooter's velocity, so its true path is
# the muzzle vector PLUS the ship's drift. Set by WeaponController at fire time.
var inherited_velocity: Vector3 = Vector3.ZERO
# Co-op: the host's bolt is authoritative and deals damage; client copies are
# visual-only (collision off) and kept in sync by the same deterministic motion.
var damaging: bool = true
var _color: Color = Color(0.4, 0.9, 1.0)
var _life: float = 0.0

func setup(p_damage: float, p_speed: float, p_target_mask: int, p_color: Color) -> void:
	damage = p_damage
	speed = p_speed
	collision_layer = 0          # nothing needs to detect the bolt itself
	collision_mask = p_target_mask
	_color = p_color

func _ready() -> void:
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.12
	capsule.height = 1.8
	mesh_inst.mesh = capsule
	mesh_inst.rotation_degrees = Vector3(90, 0, 0)  # lay the capsule along Z (the travel axis)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _color
	mat.emission_enabled = true
	mat.emission = _color
	mat.emission_energy_multiplier = 4.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.4
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	if not damaging:
		collision_mask = 0   # client-side visual copy: detects nothing

func _physics_process(delta: float) -> void:
	# Muzzle velocity along the bolt's own −Z, plus the shooter's inherited drift.
	global_position += (-global_transform.basis.z * speed + inherited_velocity) * delta
	_life += delta
	# Damaging bolts (host/solo) self-despawn; client copies wait for the host's
	# spawner despawn, with a long safety net so a missed packet can't leak them.
	if _life >= lifetime and (damaging or _life >= lifetime * 4.0):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_damage"):
		body.apply_damage(damage)
	Explosion.spawn(get_tree().current_scene, global_position, 0.6, _color)
	queue_free()
