class_name ShipController
extends CharacterBody3D
## Authoritative arcade flight controller (Simulation layer).
## Arcade 6-DOF feel per GDD §11: weighty, readable, responsive — no orbital sim.
## All tuning comes from ShipDef; no magic numbers here (GDD §30.3).

@export var ship_def: ShipDef

var current_hull: float = 0.0
var current_shield: float = 0.0
var is_boosting: bool = false
var alive: bool = true
var weapon: WeaponController   # set by main when the ship is assembled

var _mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	if ship_def == null:
		ship_def = ShipDef.new()
	# Floating mode = free 3D movement with no gravity/floor logic (space flight).
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	current_hull = ship_def.hull_max
	current_shield = ship_def.shield_max

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative

func _physics_process(delta: float) -> void:
	if not alive:
		# Coast to a stop after destruction; controls are dead.
		velocity = velocity.lerp(Vector3.ZERO, clampf(ship_def.brake_damp * delta, 0.0, 1.0))
		move_and_slide()
		return
	_steer(delta)
	_translate(delta)

func _steer(delta: float) -> void:
	# Mouse steers the nose (yaw + pitch); A/D roll the hull.
	var sens := 0.0022 * ship_def.turn_speed
	rotate_object_local(Vector3.UP, -_mouse_delta.x * sens)
	rotate_object_local(Vector3.RIGHT, -_mouse_delta.y * sens)
	_mouse_delta = Vector2.ZERO
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

## Damage flows shield-first, then hull (GDD §13). Emits via EventBus so the HUD,
## audio, and (later) ship-AI voice react without referencing this node.
func apply_damage(amount: float) -> void:
	if amount <= 0.0 or not alive:
		return
	var to_shield := minf(current_shield, amount)
	current_shield -= to_shield
	current_hull = maxf(0.0, current_hull - (amount - to_shield))
	EventBus.ship_shield_changed.emit(current_shield, ship_def.shield_max)
	EventBus.ship_hull_changed.emit(current_hull, ship_def.hull_max)
	EventBus.ship_hit.emit(amount)
	if current_hull <= 0.0:
		alive = false
		EventBus.ship_destroyed.emit()
