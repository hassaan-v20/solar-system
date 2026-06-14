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
	# Host-authoritative: only the owning peer (the host, in co-op) runs the AI;
	# clients are puppets posed by the MultiplayerSynchronizer. Always true in solo.
	if not is_multiplayer_authority():
		return
	if target == null or not is_instance_valid(target):
		# No target: coast to rest (momentum, not an instant stop).
		velocity = velocity.move_toward(Vector3.ZERO, enemy_def.accel * delta)
		move_and_slide()
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist < 0.01:
		return
	var dir := to_target / dist

	# Aim where the player WILL be — its bolts inherit its velocity, so it solves
	# the same intercept the player's lead pip does and points the nose there.
	var aim := _lead_direction(to_target)
	var desired := Basis.looking_at(aim, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired, clampf(enemy_def.turn_speed * delta, 0.0, 1.0)).orthonormalized()

	# Newtonian station-keeping: thrust to close/hold the preferred range while
	# orbiting, accelerating toward the target velocity so momentum carries. The
	# orbit makes it a moving target instead of a stationary one.
	var range_err := dist - enemy_def.preferred_range
	var radial := dir * clampf(range_err / 20.0, -1.0, 1.0)
	var tangent := dir.cross(Vector3.UP)
	if tangent.length() < 0.01:
		tangent = dir.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var desired_v := (radial + tangent * 0.6).limit_length(1.0) * enemy_def.move_speed
	velocity = velocity.move_toward(desired_v, enemy_def.accel * delta)
	move_and_slide()

	# Fire only when actually lined up on the lead point and in range.
	var aim_dot := (-global_transform.basis.z).dot(aim)
	if dist <= enemy_def.preferred_range * 1.8 and aim_dot > 0.992:
		_weapon.try_fire()

## Where to point so a bolt (muzzle speed + our own inherited velocity) intercepts
## the moving target. Falls back to aiming straight at it if there's no solution.
func _lead_direction(to_target: Vector3) -> Vector3:
	var dist := to_target.length()
	if dist < 0.001:
		return -global_transform.basis.z
	var bs: float = maxf(1.0, enemy_def.projectile_speed)
	var vt: Vector3 = target.get_velocity() if target.has_method("get_velocity") else Vector3.ZERO
	var vrel := vt - velocity
	var t := _intercept_time(to_target, vrel, bs)
	if t <= 0.0:
		return to_target / dist
	var lead := (to_target + vrel * t) / (bs * t)
	return lead.normalized() if lead.length() > 0.001 else to_target / dist

func _intercept_time(p: Vector3, vrel: Vector3, bs: float) -> float:
	var a := bs * bs - vrel.length_squared()
	var pv := p.dot(vrel)
	if absf(a) < 0.0001:
		return -p.length_squared() / (2.0 * pv) if absf(pv) > 0.0001 else 0.0
	var disc := pv * pv + a * p.length_squared()
	if disc < 0.0:
		return 0.0
	var root := sqrt(disc)
	var best := -1.0
	for tt in [(pv + root) / a, (pv - root) / a]:
		if tt > 0.0 and (best < 0.0 or tt < best):
			best = tt
	return best

# get_velocity() is inherited from CharacterBody3D (returns `velocity`), so the
# weapon's bolt-inheritance and the player's lead pip read it without an override.

func apply_damage(amount: float) -> void:
	_hull = maxf(0.0, _hull - amount)
	if _hull <= 0.0:
		Explosion.spawn(get_tree().current_scene, global_position, 2.2, Color(1.0, 0.55, 0.2))
		EventBus.enemy_destroyed.emit()
		queue_free()
