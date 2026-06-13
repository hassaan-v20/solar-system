extends Node3D
## Ghost Station — Milestone 1 bootstrap.
## Builds a flyable sector entirely in code (placeholder primitives) so the slice
## runs before any art exists. Real scenes/assets get split out in later
## milestones. Goal of M1 (GDD §27): "flying around feels acceptable."

const ASTEROID_COUNT := 140
const STAR_COUNT := 700

# Physics collision layers (1-based bit values). Friend/foe for weapons is decided
# entirely by these masks, so projectiles need no owner tracking (see projectile.gd).
const LAYER_ENVIRONMENT := 1   # asteroids / debris
const LAYER_PLAYER_SHIP := 2
const LAYER_ENEMY := 4

const RESULTS_SCENE := "res://scenes/station/results_screen.tscn"
const RESULTS_DELAY := 2.5      # let the end-of-mission overlay / explosion read

var _rng := RandomNumberGenerator.new()
var _want_capture := true
var _ship: ShipController
var _mission_def: MissionDef
var _drones_killed: int = 0
var _run_finished: bool = false

func _ready() -> void:
	_rng.randomize()
	_setup_input()
	# Use Godot's own fullscreen (a borderless window), NOT macOS native
	# fullscreen (the green button) — native fullscreen opens a separate macOS
	# Space where mouse capture / relative steering breaks.
	_apply_fullscreen(true)
	_set_capture(true)
	_build_environment()
	_build_stars()
	_ship = _build_ship()
	_build_camera(_ship)
	_build_hud(_ship)
	_build_asteroids()
	_mission_def = load("res://data/missions/ghost_station.tres")
	if _mission_def == null:
		_mission_def = MissionDef.new()
	var dock := _build_station(_mission_def.station_distance)
	_build_mission(_ship, dock, _mission_def)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.enemy_destroyed.connect(func() -> void: _drones_killed += 1)
	EventBus.mission_state_changed.connect(_on_mission_state_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse"):
		_set_capture(not _want_capture)
	elif event.is_action_pressed("toggle_fullscreen"):
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_apply_fullscreen(not is_fs)
		_set_capture(true)
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()

func _process(_delta: float) -> void:
	# macOS silently drops mouse capture when the window crosses displays or
	# Spaces (the cursor reappears and steering dies). Re-assert capture every
	# frame while focused and wanted, so it's grabbed back immediately.
	if _want_capture and get_window().has_focus() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	# Immediate re-grab on focus/enter events (Cmd-Tab, mouse re-entering), but
	# only if the player hasn't deliberately freed the mouse with Esc.
	if not _want_capture:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_WM_MOUSE_ENTER:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_capture(on: bool) -> void:
	_want_capture = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _apply_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

# ── input ─────────────────────────────────────────────────────────────────────
func _setup_input() -> void:
	# Registered in code so project.godot stays clean and layout-independent.
	var binds := {
		"thrust_forward": [KEY_W],
		"thrust_back": [KEY_S],
		"strafe_left": [KEY_Q],
		"strafe_right": [KEY_E],
		"roll_left": [KEY_A],
		"roll_right": [KEY_D],
		"boost": [KEY_SHIFT],
		"brake": [KEY_CTRL],
		"dock": [KEY_F],
		"toggle_mouse": [KEY_ESCAPE],
		"toggle_fullscreen": [KEY_F11],
		"quit_game": [KEY_F8],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

	# Primary fire on the left mouse button (works while the mouse is captured).
	if not InputMap.has_action("fire_primary"):
		InputMap.add_action("fire_primary")
	var fire_ev := InputEventMouseButton.new()
	fire_ev.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire_primary", fire_ev)

	_setup_gamepad()

## Gamepad (DualSense and any SDL-mapped pad). Bound to the SAME actions as the
## keyboard/mouse, so both work at once — only the right stick needs new code
## (see ShipController._steer). Pilot layer only; co-op roles come in M5.
func _setup_gamepad() -> void:
	# Digital actions → face/shoulder buttons. (PlayStation: A=Cross, B=Circle.)
	var pad_buttons := {
		"roll_left": JOY_BUTTON_LEFT_SHOULDER,    # L1
		"roll_right": JOY_BUTTON_RIGHT_SHOULDER,  # R1
		"brake": JOY_BUTTON_B,                     # Circle
		"dock": JOY_BUTTON_A,                      # Cross
	}
	for action in pad_buttons:
		var be := InputEventJoypadButton.new()
		be.button_index = pad_buttons[action]
		InputMap.action_add_event(action, be)

	# Analog actions → stick/trigger axes, as [axis, direction]. Left stick flies,
	# right stick steers (look_* are new, gamepad-only), triggers fire/boost.
	var pad_axes := {
		"thrust_forward": [JOY_AXIS_LEFT_Y, -1.0],
		"thrust_back": [JOY_AXIS_LEFT_Y, 1.0],
		"strafe_left": [JOY_AXIS_LEFT_X, -1.0],
		"strafe_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0],
		"look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
		"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"boost": [JOY_AXIS_TRIGGER_LEFT, 1.0],     # L2
		"fire_primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0],  # R2
	}
	for action in pad_axes:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var me := InputEventJoypadMotion.new()
		me.axis = pad_axes[action][0]
		me.axis_value = pad_axes[action][1]
		InputMap.action_add_event(action, me)
		# Lower than the 0.5 default so the sticks/triggers feel responsive.
		InputMap.action_set_deadzone(action, 0.2)

# ── world ─────────────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.1
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.20)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_stars() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 1.2
	mesh.radial_segments = 4
	mesh.rings = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = STAR_COUNT
	for i in STAR_COUNT:
		var pos := _random_unit() * _rng.randf_range(400.0, 600.0)
		var s := _rng.randf_range(0.5, 2.2)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)

func _build_ship() -> ShipController:
	var ship := ShipController.new()
	ship.name = "Wayfarer"
	# Outfit the base hull with the player's owned upgrades (M4); base .tres is
	# left untouched — UpgradeSystem returns a modified copy.
	var base_def := load("res://data/ships/wayfarer.tres")
	if base_def is ShipDef:
		ship.ship_def = UpgradeSystem.outfit(base_def, PlayerProfile.owned_upgrades)

	# Hull body (placeholder primitive)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 0.7, 3.4)
	body.mesh = box
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.60, 0.65, 0.72)
	hull_mat.metallic = 0.6
	hull_mat.roughness = 0.4
	body.material_override = hull_mat
	ship.add_child(body)

	# Glowing nose marker so the ship's facing is readable while flying.
	var nose := MeshInstance3D.new()
	var nbox := BoxMesh.new()
	nbox.size = Vector3(0.5, 0.5, 1.0)
	nose.mesh = nbox
	nose.position = Vector3(0, 0, -2.0)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(1.0, 0.55, 0.2)
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(1.0, 0.4, 0.1)
	nose.material_override = nose_mat
	ship.add_child(nose)

	# Player-ship body: collides with the environment (asteroids); enemy bolts
	# detect it via this layer.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.7, 3.4)
	col.shape = shape
	ship.add_child(col)
	ship.collision_layer = LAYER_PLAYER_SHIP
	ship.collision_mask = LAYER_ENVIRONMENT

	# Primary weapon mounted at the nose; its bolts damage the enemy layer.
	var wc := WeaponController.new()
	wc.weapon_def = load("res://data/weapons/laser_cannon_mk1.tres")
	wc.target_mask = LAYER_ENEMY
	wc.muzzle_offset = Vector3(0, 0, -2.4)
	wc.bolt_color = Color(0.4, 0.9, 1.0)
	ship.add_child(wc)
	ship.weapon = wc

	# Cargo hold (carries the Data Core / salvage this run).
	var cargo := CargoSystem.new()
	ship.add_child(cargo)
	ship.cargo = cargo

	add_child(ship)
	# Carry persisted damage into the run (repairing at the station restores it),
	# but floor it so an unrepaired ship is never launched dead/unplayable.
	ship.current_hull = ship.ship_def.hull_max * clampf(PlayerProfile.ship_hull_pct, 0.3, 1.0)
	return ship

func _build_camera(ship: ShipController) -> void:
	var cam := ChaseCamera.new()
	cam.target_path = ship.get_path()
	add_child(cam)
	cam.current = true

func _build_hud(ship: ShipController) -> void:
	var hud := ShipHUD.new()
	hud.ship = ship
	add_child(hud)

func _build_asteroids() -> void:
	for i in ASTEROID_COUNT:
		var r := _rng.randf_range(1.5, 6.0)

		# Solid rock: a StaticBody3D on the default collision layer. The ship is a
		# CharacterBody3D (also default mask), so move_and_slide stops it on impact
		# — no more flying straight through asteroids. (M2 will split these onto a
		# dedicated "environment" layer once weapons/enemies need their own.)
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_ENVIRONMENT
		# Place in a shell around origin so the spawn point stays clear.
		body.position = _random_unit() * _rng.randf_range(40.0, 260.0)
		body.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)

		var mesh_inst := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 6
		m.rings = 4
		mesh_inst.mesh = m
		var mat := StandardMaterial3D.new()
		var g := _rng.randf_range(0.25, 0.45)
		mat.albedo_color = Color(g, g * 0.95, g * 0.9)
		mat.roughness = 1.0
		mesh_inst.material_override = mat
		# Per-axis scale only lumps up the *look*; the collision sphere below stays
		# round (a fair approximation for placeholder rocks, and keeps the physics
		# shape free of the non-uniform-scale warnings Godot raises otherwise).
		var sx := _rng.randf_range(0.7, 1.4)
		var sy := _rng.randf_range(0.7, 1.4)
		var sz := _rng.randf_range(0.7, 1.4)
		mesh_inst.scale = Vector3(sx, sy, sz)
		body.add_child(mesh_inst)

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = r * (sx + sy + sz) / 3.0
		col.shape = shape
		body.add_child(col)

		add_child(body)

## Builds the derelict station (placeholder primitives) and returns its docking
## zone so the MissionManager can wire the dock objective to it.
func _build_station(distance: float) -> ShipZone:
	var station := Node3D.new()
	station.position = Vector3(0, 0, -distance)   # straight ahead of the spawn point
	add_child(station)

	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.18, 0.2, 0.24)
	hull_mat.metallic = 0.7
	hull_mat.roughness = 0.6

	# Central spine.
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 6.0
	core_mesh.bottom_radius = 6.0
	core_mesh.height = 46.0
	core.mesh = core_mesh
	core.material_override = hull_mat
	station.add_child(core)

	# A few protruding modules so the silhouette reads as a structure, not a pole.
	for spec in [Vector3(14, 6, 0), Vector3(-12, -8, 4), Vector3(0, 14, -10)]:
		var mod := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(10, 6, 8)
		mod.mesh = box
		mod.material_override = hull_mat
		mod.position = spec
		station.add_child(mod)

	# Dim red running lights so the derelict is findable in the dark sector.
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.3, 0.25)
	beacon.light_energy = 3.0
	beacon.omni_range = 60.0
	station.add_child(beacon)

	var dock := ShipZone.new()
	dock.radius = 26.0
	dock.marker_color = Color(0.3, 0.7, 1.0)
	station.add_child(dock)
	return dock

func _build_mission(ship: ShipController, dock: ShipZone, mdef: MissionDef) -> void:
	var mm := MissionManager.new()
	mm.mission_def = mdef
	mm.setup(ship, ship.cargo, dock)
	add_child(mm)

## End-of-run bookkeeping: compute the payout, persist progression, stash a
## summary for the results screen, then hand off after a short beat.
func _on_mission_state_changed(state: String) -> void:
	if state != "success" and state != "failed":
		return
	if _run_finished:
		return
	_run_finished = true
	var success := state == "success"
	var has_core: bool = _ship.cargo != null and _ship.cargo.has_item(MissionManager.DATA_CORE)
	var reward := RewardCalculator.compute(success, _drones_killed, has_core, _mission_def.reward_credits)

	PlayerProfile.credits += reward
	if success:
		PlayerProfile.mission_completions += 1
		if _ship.cargo != null:
			PlayerProfile.total_cargo_extracted += _ship.cargo.items.size()
	PlayerProfile.ship_hull_pct = clampf(_ship.current_hull / _ship.ship_def.hull_max, 0.0, 1.0)
	PlayerProfile.save_profile()
	PlayerProfile.last_run = {
		"success": success,
		"credits_earned": reward,
		"drones_killed": _drones_killed,
		"data_core": has_core,
	}

	get_tree().create_timer(RESULTS_DELAY).timeout.connect(
		func() -> void: get_tree().change_scene_to_file(RESULTS_SCENE))

func _on_ship_destroyed() -> void:
	if _ship == null:
		return
	Explosion.spawn(self, _ship.global_position, 3.5, Color(1.0, 0.55, 0.2))
	_ship.set_physics_process(false)
	if _ship.weapon != null:
		_ship.weapon.set_physics_process(false)

func _random_unit() -> Vector3:
	var v := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn())
	if v.length() < 0.001:
		v = Vector3(0, 0, 1)
	return v.normalized()
