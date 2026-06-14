class_name ShipController
extends RigidBody3D
## Authoritative Newtonian flight controller (Simulation layer).
## The ship is a true rigid body: thrust and steering are accelerations applied to
## conserved linear/angular momentum, so it coasts, drifts, and carries impacts
## (collisions transfer real momentum). Flight Assist (Z) is an RCS controller that
## nulls the velocity/spin the pilot ISN'T commanding, within a thrust budget
## (coupled flight). Switch it off for raw Newtonian drift (decoupled). All tuning
## comes from ShipDef; no magic numbers here (GDD §30.3).

@export var ship_def: ShipDef
@export var invert_pitch: bool = false   # gamepad right-stick pitch preference

var current_hull: float = 0.0
var current_shield: float = 0.0
var is_boosting: bool = false
var throttle: float = 0.0   # forward thrust 0..1 this frame; read by ShipFX for engine flare
var alive: bool = true
var flight_assist: bool = true   # on = coupled (RCS holds station); off = raw drift (read by HUD)
var weapon: WeaponController   # set by main when the ship is assembled
var cargo: CargoSystem         # set by main when the ship is assembled

# Local-space maneuvering thrust this frame (x=strafe, y=lift), −1..1. ShipFX reads
# it to puff the matching RCS nozzle; assist drift-correction feeds it too.
var rcs_local: Vector3 = Vector3.ZERO

var _mouse_delta: Vector2 = Vector2.ZERO

func _ready() -> void:
	if ship_def == null:
		ship_def = ShipDef.new()
	# Newtonian body: no gravity, no engine drag (we model thrust/RCS ourselves),
	# never sleeps (driven every step). Puppets are posed by the network, so they
	# stay kinematic-frozen and never run local physics.
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	# Sweep collisions so a fast ship can't tunnel through thin hull/asteroid geometry.
	continuous_cd = true
	mass = ship_def.mass
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = not is_multiplayer_authority()
	flight_assist = ship_def.flight_assist_default
	current_hull = ship_def.hull_max
	current_shield = ship_def.shield_max

func _unhandled_input(event: InputEvent) -> void:
	# Only the owning peer reads input (M5). Single-player has default authority.
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative is raw pixels, NOT scaled by the canvas_items stretch — so
		# steering sensitivity stays the same at any resolution.
		_mouse_delta += (event as InputEventMouseMotion).screen_relative

func _physics_process(_delta: float) -> void:
	# Keep the body simulated only on its owner; puppets stay frozen and are posed
	# by the MultiplayerSynchronizer (transform replication). Cheap, only flips on
	# an authority change.
	var mine := is_multiplayer_authority()
	if freeze == mine:
		freeze = not mine
	# Death is host-authoritative in co-op: hull is replicated from the host, so a
	# client whose ship the host killed goes dead here even though apply_damage ran
	# on the host. (In solo, apply_damage already set this.)
	if alive and current_hull <= 0.0:
		alive = false
	if mine and alive and not Settings.input_locked and Input.is_action_just_pressed("toggle_assist"):
		flight_assist = not flight_assist

## All motion runs through the physics integrator so momentum, collisions, and the
## ship's own thrusters all compose correctly. Only the owner integrates; puppets
## are frozen (this isn't called for them).
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not is_multiplayer_authority():
		return
	var dt := state.step
	if not alive:
		# Controls are dead after destruction: coast to a stop, stop spinning.
		state.linear_velocity = state.linear_velocity.move_toward(Vector3.ZERO, ship_def.brake_decel * dt)
		state.angular_velocity = state.angular_velocity.move_toward(Vector3.ZERO, ship_def.rot_assist * dt)
		return
	_integrate_rotation(state, dt)
	_integrate_translation(state, dt)

func _integrate_rotation(state: PhysicsDirectBodyState3D, dt: float) -> void:
	var basis := state.transform.basis
	# Commanded turn rate in local axes (x=pitch, y=yaw, z=roll). Mouse and the
	# gamepad stick both feed a target RATE — fast mouse motion = a faster commanded
	# turn — so steering itself has angular inertia (it ramps up and coasts).
	var pitch_dir := -1.0 if invert_pitch else 1.0
	var stick := Vector2.ZERO if Settings.input_locked else Vector2(
		Input.get_axis("look_left", "look_right"),
		Input.get_axis("look_down", "look_up"))
	var roll_in := 0.0 if Settings.input_locked else Input.get_axis("roll_right", "roll_left")
	var cmd := Vector3(
		-_mouse_delta.y * ship_def.mouse_sens + stick.y * pitch_dir * ship_def.turn_rate,
		-_mouse_delta.x * ship_def.mouse_sens + -stick.x * ship_def.turn_rate,
		roll_in * ship_def.roll_rate)
	_mouse_delta = Vector2.ZERO   # consume (it stays 0 while the menu is open; capture is off)
	cmd.x = clampf(cmd.x, -ship_def.turn_rate, ship_def.turn_rate)
	cmd.y = clampf(cmd.y, -ship_def.turn_rate, ship_def.turn_rate)
	cmd.z = clampf(cmd.z, -ship_def.roll_rate, ship_def.roll_rate)

	var w := basis.inverse() * state.angular_velocity   # current spin, local axes
	for i in 3:
		if absf(cmd[i]) > 0.0001:
			# Spin up toward the commanded rate (RCS torque budget = turn_accel).
			w[i] = move_toward(w[i], cmd[i], ship_def.turn_accel * dt)
		elif flight_assist:
			# Coupled: RCS counter-torque damps residual spin to a stop.
			w[i] = move_toward(w[i], 0.0, ship_def.rot_assist * dt)
		# Decoupled + uncommanded → keep spinning (raw Newtonian).
	state.angular_velocity = basis * w

func _integrate_translation(state: PhysicsDirectBodyState3D, dt: float) -> void:
	var basis := state.transform.basis
	# While the options menu is open the pilot inputs read neutral, so the ship just
	# coasts (assist still settles it) instead of flying on a held key.
	var locked := Settings.input_locked
	is_boosting = not locked and Input.is_action_pressed("boost")
	var braking := not locked and Input.is_action_pressed("brake")
	var thrust := 0.0 if locked else Input.get_axis("thrust_back", "thrust_forward")   # +forward, −reverse
	var strafe := 0.0 if locked else Input.get_axis("strafe_left", "strafe_right")
	var lift := 0.0 if locked else Input.get_axis("thrust_down", "thrust_up")
	throttle = clampf(thrust, 0.0, 1.0)   # only forward thrust flares the main engines

	# Main engine is strong forward, weaker in reverse; RCS handles strafe + lift.
	var boost_mult := ship_def.boost_accel_mult if is_boosting else 1.0
	var fwd_accel := (ship_def.acceleration if thrust >= 0.0 else ship_def.reverse_accel) * boost_mult
	var local_thrust := Vector3(
		strafe * ship_def.strafe_accel,
		lift * ship_def.strafe_accel,
		-thrust * fwd_accel)               # nose is local −Z
	state.linear_velocity += basis * local_thrust * dt

	# FX: what the maneuvering thrusters are doing this frame (stick command first).
	rcs_local = Vector3(strafe, lift, 0.0)

	if braking:
		# Active brake: a firm stop on every axis.
		state.linear_velocity = state.linear_velocity.move_toward(Vector3.ZERO, ship_def.brake_decel * dt)
	elif flight_assist:
		_apply_flight_assist(state, dt, thrust, strafe, lift)

	_govern_speed(state, braking)

## Flight assist (coupled). Works in ship-local space and nulls only the velocity
## the pilot isn't commanding — uncommanded fore/aft, sideways, and vertical drift
## bleed toward rest, capped by the RCS decel budget so it reads as thrusters
## firing, not magic. The ship tracks its nose and settles when released; with
## assist off this never runs and momentum is conserved.
func _apply_flight_assist(state: PhysicsDirectBodyState3D, dt: float, thrust: float, strafe: float, lift: float) -> void:
	var basis := state.transform.basis
	var v := basis.inverse() * state.linear_velocity   # local-space velocity
	var before := v
	v.x = _null_axis(v.x, absf(strafe) > 0.01, dt)
	v.y = _null_axis(v.y, absf(lift) > 0.01, dt)
	v.z = _null_axis(v.z, absf(thrust) > 0.01, dt)
	state.linear_velocity = basis * v
	# If the pilot gave no lateral/vertical stick, surface the assist's own drift
	# correction so the FX still puffs the RCS while it holds station.
	if absf(strafe) < 0.01:
		rcs_local.x = clampf((before.x - v.x) / (ship_def.assist_decel * dt + 0.0001), -1.0, 1.0)
	if absf(lift) < 0.01:
		rcs_local.y = clampf((before.y - v.y) / (ship_def.assist_decel * dt + 0.0001), -1.0, 1.0)

## Reduce one velocity axis toward zero: proportional for smoothness, but capped by
## the RCS thrust budget so the assist can't exceed what the thrusters could do.
func _null_axis(v: float, commanded: bool, dt: float) -> float:
	if commanded:
		return v
	var want := -v * clampf(ship_def.assist_response * dt, 0.0, 1.0)
	var budget := ship_def.assist_decel * dt
	return v + clampf(want, -budget, budget)

## Speed envelope. Assist and the brake hold the ship inside its powered cap (boost
## speed while boosting, else max speed). A raw Newtonian coast keeps whatever
## momentum it has, bounded only by the absolute boost ceiling — so boosting up and
## releasing leaves you sliding fast, which is the whole point of inertia.
func _govern_speed(state: PhysicsDirectBodyState3D, braking: bool) -> void:
	var sp := state.linear_velocity.length()
	if flight_assist or braking:
		var cap := ship_def.boost_speed if is_boosting else ship_def.max_speed
		if sp > cap:
			state.linear_velocity *= cap / sp
	elif sp > ship_def.boost_speed:
		state.linear_velocity *= ship_def.boost_speed / sp

func get_speed() -> float:
	return linear_velocity.length()

## World-space velocity — read by gunnery (bolts inherit it) and the HUD lead pip.
func get_velocity() -> Vector3:
	return linear_velocity

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
