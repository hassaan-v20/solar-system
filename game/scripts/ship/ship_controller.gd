class_name ShipController
extends CharacterBody3D
## Authoritative arcade flight controller (Simulation layer).
## Arcade 6-DOF feel per GDD §11: weighty, readable, responsive — no orbital sim.
## All tuning comes from ShipDef; no magic numbers here (GDD §30.3).

@export var ship_def: ShipDef

var current_hull: float = 0.0
var current_shield: float = 0.0
var is_boosting: bool = false
var is_dead: bool = false

const SHIELD_REGEN := 12.0          # shield points per second
const REGEN_DELAY := 6.0            # seconds after a hit before shields recharge

var _mouse_delta: Vector2 = Vector2.ZERO
var _since_hit: float = 999.0

func _ready() -> void:
	if ship_def == null:
		ship_def = ShipDef.new()
	add_to_group("player")
	# Floating mode = free 3D movement with no gravity/floor logic (space flight).
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	current_hull = ship_def.hull_max
	current_shield = ship_def.shield_max

func get_team() -> String:
	return "player"

func take_damage(amount: float) -> void:
	if is_dead:
		return
	_since_hit = 0.0
	var to_shield := minf(current_shield, amount)
	current_shield -= to_shield
	current_hull -= (amount - to_shield)
	EventBus.ship_shield_changed.emit(current_shield, ship_def.shield_max)
	EventBus.ship_hull_changed.emit(current_hull, ship_def.hull_max)
	EventBus.player_hit.emit()
	if current_hull <= 0.0:
		current_hull = 0.0
		is_dead = true
		EventBus.ship_destroyed.emit()

func heal(amount: float, kind: String) -> void:
	if kind == "hull":
		current_hull = minf(ship_def.hull_max, current_hull + amount)
		EventBus.ship_hull_changed.emit(current_hull, ship_def.hull_max)
	else:
		current_shield = minf(ship_def.shield_max, current_shield + amount)
		EventBus.ship_shield_changed.emit(current_shield, ship_def.shield_max)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative

func _physics_process(delta: float) -> void:
	_steer(delta)
	_translate(delta)
	_regen(delta)

func _regen(delta: float) -> void:
	_since_hit += delta
	if not is_dead and _since_hit > REGEN_DELAY and current_shield < ship_def.shield_max:
		current_shield = minf(ship_def.shield_max, current_shield + SHIELD_REGEN * delta)
		EventBus.ship_shield_changed.emit(current_shield, ship_def.shield_max)

func _steer(delta: float) -> void:
	# Mouse and the right stick both steer the nose (yaw + pitch); A/D or L1/R1 roll.
	var sens := 0.0022 * ship_def.turn_speed
	rotate_object_local(Vector3.UP, -_mouse_delta.x * sens)
	rotate_object_local(Vector3.RIGHT, -_mouse_delta.y * sens)
	_mouse_delta = Vector2.ZERO
	# Right stick: continuous analog look, scaled by the same turn_speed as the mouse.
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotate_object_local(Vector3.UP, -look.x * ship_def.turn_speed * delta)
	rotate_object_local(Vector3.RIGHT, -look.y * ship_def.turn_speed * delta)
	var roll_input := Input.get_axis("roll_right", "roll_left")
	rotate_object_local(Vector3.FORWARD, roll_input * ship_def.roll_speed * delta)

func _translate(delta: float) -> void:
	is_boosting = Input.is_action_pressed("boost")
	var braking := Input.is_action_pressed("brake")
	var thrust := Input.get_axis("thrust_back", "thrust_forward")
	var strafe := Input.get_axis("strafe_left", "strafe_right")

	var accel := ship_def.acceleration * (ship_def.boost_accel_mult if is_boosting else 1.0)
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	velocity += forward * thrust * accel * delta
	velocity += right * strafe * ship_def.strafe_accel * delta

	# Mild damping gives the "weighty but controllable" feel; brake adds more.
	var damp := ship_def.brake_damp if braking else ship_def.linear_damp
	velocity = velocity.lerp(Vector3.ZERO, clampf(damp * delta, 0.0, 1.0))

	var cap := ship_def.boost_speed if is_boosting else ship_def.max_speed
	if velocity.length() > cap:
		velocity = velocity.normalized() * cap

	move_and_slide()

func get_speed() -> float:
	return velocity.length()
