class_name EnemyDroneAI
extends CharacterBody3D
## Light combat drone (AI layer). Seeks the player, holds a preferred range,
## fires bolts, takes damage, and explodes. Built in code (no scene yet).

signal destroyed(score: int, at: Vector3)

@export var enemy_def: EnemyDef

var target: Node3D
var world: Node3D
var current_hull: float = 0.0

var _weapon: WeaponController
var _body_mat: StandardMaterial3D
var _flash_t: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if enemy_def == null:
		enemy_def = EnemyDef.new()
	current_hull = enemy_def.hull_max
	_build_visual()
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
	var to := target.global_position - global_position
	var dist := to.length()
	if dist > enemy_def.aggro_range or dist < 0.5:
		velocity = velocity.lerp(Vector3.ZERO, clampf(0.5 * delta, 0.0, 1.0))
	else:
		var dir := to / dist
		var desired: Vector3
		if dist > enemy_def.preferred_range * 1.1:
			desired = dir
		elif dist < enemy_def.preferred_range * 0.8:
			desired = -dir
		else:
			desired = dir.cross(Vector3.UP).normalized()   # strafe to feel alive
		velocity += desired * enemy_def.accel * delta
		if velocity.length() > enemy_def.move_speed:
			velocity = velocity.normalized() * enemy_def.move_speed
		look_at(target.global_position, Vector3.UP)
		if _weapon != null:
			_weapon.fire_at(target.global_position)
	move_and_slide()

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(2.4, 1.4, 2.4)
	body.mesh = prism
	body.rotation_degrees = Vector3(-90, 0, 0)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = enemy_def.body_color
	_body_mat.metallic = 0.5
	_body_mat.roughness = 0.5
	_body_mat.emission_enabled = true
	_body_mat.emission = enemy_def.body_color
	_body_mat.emission_energy_multiplier = 1.6
	body.material_override = _body_mat
	add_child(body)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.6, 2.4)
	col.shape = shape
	add_child(col)

func _build_weapon() -> void:
	_weapon = WeaponController.new()
	var wd := WeaponDef.new()
	wd.damage = enemy_def.damage
	wd.fire_rate = enemy_def.fire_rate
	wd.weapon_range = 600.0
	_weapon.weapon_def = wd
	_weapon.team = "enemy"
	_weapon.bolt_color = Color(1.0, 0.45, 0.25)
	_weapon.muzzle_offset = Vector3(0, 0, -2.0)
	add_child(_weapon)
	_weapon.world = world

func _die() -> void:
	destroyed.emit(enemy_def.score, global_position)
	_spawn_explosion(global_position)
	queue_free()

func _spawn_explosion(at: Vector3) -> void:
	if world == null:
		return
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.5
	s.height = 3.0
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
	tw.tween_property(fx, "scale", Vector3.ONE * 4.0, 0.4)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(fx.queue_free)
