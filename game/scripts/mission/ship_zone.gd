class_name ShipZone
extends Area3D
## Simulation: a spherical trigger that fires when the player ship enters/exits,
## plus its own translucent glowing marker so the objective is visible from afar.
## Used for both the docking zone and the extraction point (GDD §26.3–26.4).
## Only the player ship (collision layer 2, see main.gd) triggers it.

signal ship_entered
signal ship_exited

@export var radius: float = 20.0
@export var marker_color: Color = Color(0.3, 0.7, 1.0)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2          # LAYER_PLAYER_SHIP
	monitoring = true

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.10)
	mat.emission_enabled = true
	mat.emission = marker_color
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	body_entered.connect(func(_b: Node) -> void: ship_entered.emit())
	body_exited.connect(func(_b: Node) -> void: ship_exited.emit())
