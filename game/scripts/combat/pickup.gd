class_name Pickup
extends Area3D
## A floating reward orb dropped by enemies. Heals the player's shield or hull on
## touch. Built in code (no scene yet).

var kind: String = "shield"        # "shield" | "hull"
var amount: float = 120.0
var lifetime: float = 18.0

func _ready() -> void:
	monitoring = true
	var col := Color(0.4, 0.8, 1.0) if kind == "shield" else Color(0.4, 1.0, 0.5)
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.9
	s.height = 1.8
	mesh.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2                # generous grab radius
	shape.shape = sph
	add_child(shape)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	rotate_y(delta * 1.5)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("heal"):
		body.heal(amount, kind)
		EventBus.pickup_collected.emit(kind)
		queue_free()
