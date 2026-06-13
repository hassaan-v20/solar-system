class_name Projectile
extends Area3D
## A visible energy bolt (Combat layer). Travels straight, damages the first body
## on the opposing team it touches, and expires after a lifetime. Built in code
## so no scene asset is needed yet.

var team: String = "player"            # "player" or "enemy"
var damage: float = 25.0
var speed: float = 200.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 4.0
var color: Color = Color(0.5, 0.9, 1.0)
var homing: bool = false
var turn_rate: float = 2.6

func _ready() -> void:
	monitoring = true
	monitorable = false
	# Visual bolt.
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 1.8
	capsule.radial_segments = 6
	capsule.rings = 1
	mesh.mesh = capsule
	mesh.rotation_degrees = Vector3(90, 0, 0)   # point the capsule along -Z/travel
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mesh.material_override = mat
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.5
	shape.shape = sph
	add_child(shape)

	# Aim the whole bolt down its travel direction.
	if direction.length() > 0.001 and absf(direction.normalized().dot(Vector3.UP)) < 0.99:
		look_at(global_position + direction, Vector3.UP)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if homing:
		var tgt := _nearest_target()
		if tgt != null:
			var want := (tgt.global_position - global_position).normalized()
			direction = direction.lerp(want, clampf(turn_rate * delta, 0.0, 1.0)).normalized()
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _nearest_target() -> Node3D:
	var group := "enemy" if team == "player" else "player"
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		var n3 := n as Node3D
		if n3 == null:
			continue
		var d := global_position.distance_squared_to(n3.global_position)
		if d < best_d:
			best_d = d
			best = n3
	return best

func _on_body_entered(body: Node) -> void:
	var target_group := "enemy" if team == "player" else "player"
	if body.is_in_group(target_group) and body.has_method("take_damage"):
		body.take_damage(damage)
		EventBus.hit_landed.emit(team, global_position)
		queue_free()
