class_name EnemyDroneAI
extends CharacterBody3D
## Combat enemy (AI layer). Two behaviours from data: "orbit" (hold range and
## shoot) and "rush" (kamikaze charge). Bosses are just big, tanky orbiters with
## the is_boss flag for HUD treatment. Built in code (no scene yet).

signal destroyed(score: int, at: Vector3)

@export var enemy_def: EnemyDef

var target: Node3D
var world: Node3D
var current_hull: float = 0.0

var _weapon: WeaponController
var _body_mat: StandardMaterial3D
var _flash_t: float = 0.0
var _ram_cd: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if enemy_def == null:
		enemy_def = EnemyDef.new()
	current_hull = enemy_def.hull_max
	_build_visual()
	if enemy_def.behavior != "rush":
		_build_weapon()

func get_team() -> String:
	return "enemy"

func take_damage(amount: float) -> void:
	current_hull -= amount
	_flash_t = 0.12
	if current_hull <= 0.0:
		_die()

func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		_body_mat.emission_energy_multiplier = 6.0 if _flash_t > 0.0 else 1.6

func _physics_process(delta: float) -> void:
	if target == null:
		return
	_ram_cd = maxf(0.0, _ram_cd - delta)
	var to := target.global_position - global_position
	var dist := to.length()
	if dist < 0.5:
		move_and_slide()
		return
	var dir := to / dist

	if enemy_def.behavior == "rush":
		velocity += dir * enemy_def.accel * delta
		if velocity.length() > enemy_def.move_speed:
			velocity = velocity.normalized() * enemy_def.move_speed
		look_at(target.global_position, Vector3.UP)
		if dist < 5.5 and target.has_method("take_damage"):
			target.take_damage(enemy_def.contact_damage)
			_die()                              # kamikaze
			return
	elif dist > enemy_def.aggro_range:
		velocity = velocity.lerp(Vector3.ZERO, clampf(0.5 * delta, 0.0, 1.0))
	else:
		var desired: Vector3
		if dist > enemy_def.preferred_range * 1.1:
			desired = dir
		elif dist < enemy_def.preferred_range * 0.8:
			desired = -dir
		else:
			desired = dir.cross(Vector3.UP).normalized()
		velocity += desired * enemy_def.accel * delta
		if velocity.length() > enemy_def.move_speed:
			velocity = velocity.normalized() * enemy_def.move_speed
		look_at(target.global_position, Vector3.UP)
		if _weapon != null:
			_weapon.fire_at(target.global_position)
	move_and_slide()

func _build_visual() -> void:
	var s := enemy_def.body_size
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = enemy_def.body_color
	_body_mat.metallic = 0.55
	_body_mat.roughness = 0.45
	_body_mat.emission_enabled = true
	_body_mat.emission = enemy_def.body_color
	_body_mat.emission_energy_multiplier = 1.6
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.9, 0.5)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.7, 0.3)
	core_mat.emission_energy_multiplier = 4.0

	var rush := enemy_def.behavior == "rush"
	# Body: a sleek dart for rushers, a chunkier hull for the rest.
	var body := BoxMesh.new()
	body.size = Vector3(s * 0.5, s * 0.4, s * 1.5) if rush else Vector3(s * 0.95, s * 0.5, s * 0.95)
	_epart(body, Vector3.ZERO, Vector3.ZERO, _body_mat)
	# Forward nose.
	var nose := PrismMesh.new()
	nose.size = Vector3(s * 0.5, s * 0.4, s * 0.8)
	_epart(nose, Vector3(0, 0, -s * 0.85), Vector3(90, 0, 0), _body_mat)
	# Swept fins.
	var fin := BoxMesh.new()
	fin.size = Vector3(s * 1.3, s * 0.08, s * 0.55)
	_epart(fin, Vector3(-s * 0.55, 0, s * 0.2), Vector3(0, -20, 0), _body_mat)
	_epart(fin, Vector3(s * 0.55, 0, s * 0.2), Vector3(0, 20, 0), _body_mat)
	# Glowing core / eye.
	var core := SphereMesh.new()
	core.radius = s * 0.2
	core.height = s * 0.4
	_epart(core, Vector3(0, 0, -s * 0.15), Vector3.ZERO, core_mat)
	if enemy_def.is_boss:
		var pod := BoxMesh.new()
		pod.size = Vector3(s * 0.4, s * 0.5, s * 1.2)
		_epart(pod, Vector3(-s * 0.7, 0, s * 0.1), Vector3.ZERO, _body_mat)
		_epart(pod, Vector3(s * 0.7, 0, s * 0.1), Vector3.ZERO, _body_mat)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(s * 1.3, s * 0.7, s * 1.4)
	col.shape = shape
	add_child(col)

func _epart(mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	add_child(mi)

func _build_weapon() -> void:
	_weapon = WeaponController.new()
	var wd := WeaponDef.new()
	wd.damage = enemy_def.damage
	wd.fire_rate = enemy_def.fire_rate
	wd.weapon_range = 600.0
	_weapon.weapon_def = wd
	_weapon.team = "enemy"
	_weapon.bolt_color = Color(1.0, 0.45, 0.25)
	_weapon.muzzle_offset = Vector3(0, 0, -enemy_def.body_size)
	add_child(_weapon)
	_weapon.world = world

func _die() -> void:
	destroyed.emit(enemy_def.score, global_position)
	EventBus.enemy_died.emit(global_position)
	_spawn_explosion(global_position)
	_maybe_drop()
	queue_free()

func _maybe_drop() -> void:
	if world == null or randf() > enemy_def.drop_chance:
		return
	var pk := Pickup.new()
	pk.kind = "hull" if randf() < 0.4 else "shield"
	pk.amount = 150.0 if pk.kind == "shield" else 120.0
	world.add_child(pk)
	pk.global_position = global_position

func _spawn_explosion(at: Vector3) -> void:
	if world == null:
		return
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	var rad := 1.5 * (enemy_def.body_size / 2.4)
	s.radius = rad
	s.height = rad * 2.0
	fx.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.7, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 5.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx.material_override = m
	world.add_child(fx)
	fx.global_position = at
	var tw := fx.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fx, "scale", Vector3.ONE * 4.0, 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(fx.queue_free)
