class_name EnemyDrone
extends CharacterBody3D
## Simulation: a light drone that slews to face the player, holds its preferred
## range, and fires when roughly aimed. Host-authoritative-ready — it never reads
## the camera/HUD or player input, only its target's transform. Tuning from
## EnemyDef (GDD §30.3).

const MODEL_PATH := "res://assets/models/enemies/scifi_drone.glb"
const MODEL_SCALE := 1.1
const MODEL_EULER := Vector3(0, 0, 0)   # flip Y to 180 if the guns point backward
const MODEL_CENTER := Vector3(-0.025, 0.07, 0.0)

@export var enemy_def: EnemyDef
var target: Node3D

var _hull: float = 0.0
var _weapon: WeaponController

func _ready() -> void:
	if enemy_def == null:
		enemy_def = EnemyDef.new()
	_hull = enemy_def.hull_max
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Layer constants mirror main.gd: 4 = enemy. Mask 0 = phases through the
	# environment (keeps the chase AI simple); it's still detectable by bolts.
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemies")
	_build_body()
	_build_weapon()

func _build_body() -> void:
	# Visual: the imported drone model; falls back to a red box if not imported yet.
	var model := ModelUtil.spawn(MODEL_PATH, MODEL_SCALE, MODEL_EULER, MODEL_CENTER)
	if model != null:
		add_child(model)
	else:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 1.0, 2.2)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.10, 0.12)
		mat.metallic = 0.4
		mat.roughness = 0.5
		mat.emission_enabled = true
		mat.emission = Color(0.85, 0.18, 0.12)
		mat.emission_energy_multiplier = 0.7
		mesh_inst.material_override = mat
		add_child(mesh_inst)

	# Hitbox stays a simple box regardless of the visual.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.0, 2.2)
	col.shape = shape
	add_child(col)

func _build_weapon() -> void:
	_weapon = WeaponController.new()
	_weapon.auto_fire = true
	_weapon.target_mask = 2          # player_ship layer (see main.gd)
	_weapon.bolt_color = Color(1.0, 0.5, 0.15)
	_weapon.muzzle_offset = Vector3(0, 0, -1.6)
	var wd := WeaponDef.new()
	wd.damage = enemy_def.weapon_damage
	wd.fire_rate = enemy_def.fire_rate
	wd.projectile_speed = enemy_def.projectile_speed
	wd.max_heat = 1.0e9              # drones never overheat
	_weapon.weapon_def = wd
	add_child(_weapon)

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist < 0.01:
		return
	var dir := to_target / dist

	# Slew to face the player.
	var desired := Basis.looking_at(dir, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired, clampf(enemy_def.turn_speed * delta, 0.0, 1.0)).orthonormalized()

	# Close to, or back off toward, the preferred range.
	var range_err := dist - enemy_def.preferred_range
	var want := Vector3.ZERO if absf(range_err) < 4.0 else dir * signf(range_err) * enemy_def.move_speed
	velocity = velocity.lerp(want, clampf(2.0 * delta, 0.0, 1.0))
	move_and_slide()

	# Fire when within engagement range and lined up.
	var aim_dot := (-global_transform.basis.z).dot(dir)
	if dist <= enemy_def.preferred_range * 1.6 and aim_dot > 0.95:
		_weapon.try_fire()

func apply_damage(amount: float) -> void:
	_hull = maxf(0.0, _hull - amount)
	if _hull <= 0.0:
		Explosion.spawn(get_tree().current_scene, global_position, 2.2, Color(1.0, 0.55, 0.2))
		EventBus.enemy_destroyed.emit()
		queue_free()
