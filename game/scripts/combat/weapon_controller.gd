class_name WeaponController
extends Node3D
## Fires projectiles from a WeaponDef (Combat layer). Tracks heat so sustained
## fire overheats. Used by the player (polls the "fire" action) and by enemy AI
## (calls fire_at).

@export var weapon_def: WeaponDef
@export var team: String = "player"
@export var poll_input: bool = false          # true for the player ship
@export var bolt_color: Color = Color(0.5, 0.9, 1.0)

var world: Node3D                              # where projectiles get parented
var muzzle_offset: Vector3 = Vector3(0, 0, -2.5)
var heat: float = 0.0
var overheated: bool = false

var _cooldown: float = 0.0

func _ready() -> void:
	if weapon_def == null:
		weapon_def = WeaponDef.new()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	heat = maxf(0.0, heat - weapon_def.cooldown_rate * delta)
	if overheated and heat <= weapon_def.max_heat * 0.4:
		overheated = false
	if poll_input and Input.is_action_pressed("fire"):
		var parent3d := get_parent() as Node3D
		if parent3d != null:
			_try_fire(-parent3d.global_transform.basis.z)

func fire_at(target_pos: Vector3) -> void:
	var dir := (target_pos - global_position).normalized()
	_try_fire(dir)

func _try_fire(dir: Vector3) -> void:
	if overheated or _cooldown > 0.0 or world == null:
		return
	_cooldown = 1.0 / maxf(0.1, weapon_def.fire_rate)
	heat += weapon_def.heat_per_shot
	if heat >= weapon_def.max_heat:
		heat = weapon_def.max_heat
		overheated = true

	var p := Projectile.new()
	p.team = team
	p.damage = weapon_def.damage
	p.speed = weapon_def.weapon_range / 4.0 + 120.0
	p.direction = dir.normalized()
	p.color = bolt_color
	world.add_child(p)
	var origin := get_parent() as Node3D
	p.global_position = origin.global_position + origin.global_transform.basis * muzzle_offset

func heat_fraction() -> float:
	return heat / maxf(1.0, weapon_def.max_heat)
