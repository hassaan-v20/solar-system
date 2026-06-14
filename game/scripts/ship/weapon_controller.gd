class_name WeaponController
extends Node3D
## Simulation: fires a primary weapon, rate-limited and heat-limited. Mounted as a
## child of whoever owns it (ship or drone); its transform is the muzzle frame.
## Tuning comes from WeaponDef (GDD §30.3). The player reads fire input directly
## here, matching the M1 ship controller; the intent/RPC split lands at M5 (net).

@export var weapon_def: WeaponDef
@export var target_mask: int = 0                    # collision layer projectiles damage
@export var muzzle_offset: Vector3 = Vector3(0, 0, -2.0)
@export var bolt_color: Color = Color(0.4, 0.9, 1.0)
@export var auto_fire: bool = false                 # true = driven by try_fire() (enemies)
@export var fire_action: String = "fire_primary"    # used only when auto_fire is false

var heat: float = 0.0
var _cooldown: float = 0.0

func _ready() -> void:
	if weapon_def == null:
		weapon_def = WeaponDef.new()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	heat = maxf(0.0, heat - weapon_def.cooldown_rate * delta)
	# Player weapons fire from local input only on the owning peer (M5); drones use
	# auto_fire (driven by their host-run AI). Single-player has default authority.
	if not auto_fire and is_multiplayer_authority() and not Settings.input_locked and Input.is_action_pressed(fire_action):
		try_fire()

## Returns true if a bolt was actually fired (not on cooldown / overheated).
func try_fire() -> bool:
	if _cooldown > 0.0:
		return false
	if heat + weapon_def.heat_per_shot > weapon_def.max_heat:
		return false
	var xform := Transform3D(global_transform.basis, global_transform * muzzle_offset)
	# Route through CombatNet so the bolt is host-authoritative in co-op (and still
	# local in solo). Fall back to a direct spawn if no CombatNet is present (tests).
	var combat := get_tree().get_first_node_in_group("combat_net")
	if combat != null:
		combat.fire(xform, _shooter_velocity(), weapon_def.damage, target_mask,
			bolt_color, weapon_def.projectile_speed)
	else:
		var bolt := Projectile.new()
		bolt.setup(weapon_def.damage, weapon_def.projectile_speed, target_mask, bolt_color)
		bolt.inherited_velocity = _shooter_velocity()
		get_tree().current_scene.add_child(bolt)
		bolt.global_transform = xform
	_cooldown = 1.0 / maxf(0.01, weapon_def.fire_rate)
	heat += weapon_def.heat_per_shot
	return true

## The mount's owner (ship or drone) supplies its velocity so bolts inherit it.
func _shooter_velocity() -> Vector3:
	var owner_node := get_parent()
	if owner_node != null and owner_node.has_method("get_velocity"):
		return owner_node.get_velocity()
	return Vector3.ZERO
