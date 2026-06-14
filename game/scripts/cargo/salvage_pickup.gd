class_name SalvagePickup
extends Area3D
## A floating salvage crate the player flies into to collect (GDD §14, salvage).
## It goes into the ship's bounded cargo hold and is only banked as credits if the
## run extracts — die first and it's lost. main._build_salvage sets value/tier and
## attaches a crate model; this node builds the grab trigger + a tier-coloured beacon.

var value: int = 50
var salvage_id: String = "salvage"
var tier_color: Color = Color(0.5, 1.0, 0.7)

var _spin: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2          # LAYER_PLAYER_SHIP (see main.gd) — only the ship grabs it
	monitoring = true

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.0          # generous grab radius so collecting feels good
	col.shape = shape
	add_child(col)

	# Tier-coloured beacon so crates are findable in the dark sector.
	var light := OmniLight3D.new()
	light.light_color = tier_color
	light.light_energy = 2.5
	light.omni_range = 16.0
	add_child(light)

	var halo := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	halo.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(tier_color.r, tier_color.g, tier_color.b, 0.35)
	m.emission_enabled = true
	m.emission = tier_color
	m.emission_energy_multiplier = 3.0
	halo.material_override = m
	add_child(halo)

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_spin += delta
	rotation.y = _spin * 0.6     # slow idle spin so it reads as a loose object

func _on_body_entered(body: Node) -> void:
	var ship := body as ShipController
	if ship == null or ship.cargo == null:
		return
	if ship.cargo.add_salvage(salvage_id, value):
		EventBus.salvage_collected.emit(value)
		Explosion.spawn(get_tree().current_scene, global_position, 0.9, tier_color)
		queue_free()
	# Hold full → leave it floating; the HUD shows CARGO full and the player chooses.
