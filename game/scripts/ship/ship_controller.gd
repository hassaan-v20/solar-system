class_name ShipController
extends CharacterBody3D
## Authoritative arcade flight controller (Simulation layer).
## Arcade 6-DOF feel per GDD §11: weighty, readable, responsive — no orbital sim.
## All tuning comes from ShipDef; no magic numbers here (GDD §30.3).

@export var ship_def: ShipDef
@export var invert_pitch: bool = false   # gamepad right-stick pitch preference

# After a collision deals damage, ignore further impact damage for this long, so a
# sustained scrape against a rock doesn't drain the hull every physics frame.
const IMPACT_COOLDOWN := 0.35

var current_hull: float = 0.0
var current_shield: float = 0.0
var is_boosting: bool = false
var throttle: float = 0.0   # forward thrust 0..1 this frame; read by ShipFX for engine flare
var alive: bool = true
var weapon: WeaponController   # set by main when the ship is assembled
var cargo: CargoSystem         # set by main when the ship is assembled

var _mouse_delta: Vector2 = Vector2.ZERO
var _impact_cooldown: float = 0.0

func _ready() -> void:
	if ship_def == null:
		ship_def = ShipDef.new()
	# Floating mode = free 3D movement with no gravity/floor logic (space flight).
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	current_hull = ship_def.hull_max
	current_shield = ship_def.shield_max

func _unhandled_input(event: InputEvent) -> void:
	# Only the peer that owns this ship reads input for it (M5). In single-player no
	# peer is assigned, so skip the authority gate entirely (is_multiplayer_authority()
	# would be false against a null peer and silently swallow all input).
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative

func _physics_process(delta: float) -> void:
	# Remote ships are puppets driven by the network (M5); only the owning peer
	# simulates. In single-player no peer is assigned, so skip the gate and always
	# simulate (is_multiplayer_authority() is false against a null peer).
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	if not alive:
		# Coast to a stop after destruction; controls are dead.
		velocity = velocity.lerp(Vector3.ZERO, clampf(ship_def.brake_damp * delta, 0.0, 1.0))
		move_and_slide()
		return
	_steer(delta)
	_translate(delta)

func _steer(delta: float) -> void:
	# Mouse steers the nose (yaw + pitch) via accumulated motion this frame.
	var sens := 0.0022 * ship_def.turn_speed
	rotate_object_local(Vector3.UP, -_mouse_delta.x * sens)
	rotate_object_local(Vector3.RIGHT, -_mouse_delta.y * sens)
	_mouse_delta = Vector2.ZERO

	# Gamepad right stick steers too, as a turn rate (turn_speed in rad/s). Matches
	# the mouse's directions; pitch can be inverted per player preference.
	var stick := Vector2(
		Input.get_axis("look_left", "look_right"),
		Input.get_axis("look_down", "look_up"))
	if stick != Vector2.ZERO:
		var pitch_dir := -1.0 if invert_pitch else 1.0
		rotate_object_local(Vector3.UP, -stick.x * ship_def.turn_speed * delta)
		rotate_object_local(Vector3.RIGHT, stick.y * pitch_dir * ship_def.turn_speed * delta)

	var roll_input := Input.get_axis("roll_right", "roll_left")
	rotate_object_local(Vector3.FORWARD, roll_input * ship_def.roll_speed * delta)

func _translate(delta: float) -> void:
	is_boosting = Input.is_action_pressed("boost")
	var braking := Input.is_action_pressed("brake")
	var thrust := Input.get_axis("thrust_back", "thrust_forward")
	var strafe := Input.get_axis("strafe_left", "strafe_right")
	throttle = clampf(thrust, 0.0, 1.0)   # only forward thrust flares the engines

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

	# Remember the velocity we're carrying *into* the move; move_and_slide() then
	# strips the component that runs into any surface, and _resolve_impacts reads
	# that lost component back to size the hit.
	var incoming := velocity
	move_and_slide()
	_resolve_impacts(incoming)

## Turns physical contact into game feel: damage scaled to how hard you hit, a
## rebound off the surface so you don't just stick to it, an impact spark, and —
## via apply_damage → EventBus.ship_hit — the camera shake. Anything we ram that
## can take damage (e.g. a drone) gets hurt too. The cooldown keeps a sustained
## scrape from re-damaging every frame, but the bounce still applies so we slide free.
func _resolve_impacts(incoming_vel: Vector3) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var normal := c.get_normal()
		# Speed at which we drove into this surface (motion along the inward normal).
		var impact_speed := incoming_vel.dot(-normal)
		if impact_speed < ship_def.collision_min_speed:
			continue
		# Physical rebound: push back out along the normal, shedding energy.
		velocity += normal * impact_speed * ship_def.collision_restitution
		if _impact_cooldown > 0.0:
			break
		_impact_cooldown = IMPACT_COOLDOWN
		var severity := impact_speed - ship_def.collision_min_speed
		var dmg := severity * ship_def.collision_damage_per_speed
		apply_damage(dmg)   # shield→hull, and emits ship_hit (drives the camera shake)
		var collider := c.get_collider()
		if collider != null and collider.has_method("apply_damage"):
			collider.apply_damage(dmg * 0.5)
		Explosion.spawn(get_tree().current_scene, c.get_position(),
			clampf(0.4 + severity * 0.025, 0.4, 1.6), Color(1.0, 0.72, 0.4))
		break   # one impact resolved per frame is plenty

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
