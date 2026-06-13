extends Node3D
## Ghost Station — Milestone 1 bootstrap.
## Builds a flyable sector entirely in code (placeholder primitives) so the slice
## runs before any art exists. Real scenes/assets get split out in later
## milestones. Goal of M1 (GDD §27): "flying around feels acceptable."

const ASTEROID_COUNT := 140
const STAR_COUNT := 700

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_setup_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	_build_stars()
	var ship := _build_ship()
	_build_camera(ship)
	_build_hud(ship)
	_build_asteroids()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()

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
		"toggle_mouse": [KEY_ESCAPE],
		"quit_game": [KEY_F8],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

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
	var def := load("res://data/ships/wayfarer.tres")
	if def is ShipDef:
		ship.ship_def = def

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

	# Collision (unused in M1 but keeps the body ready for M2 hit detection).
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.7, 3.4)
	col.shape = shape
	ship.add_child(col)

	add_child(ship)
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
		var a := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := _rng.randf_range(1.5, 6.0)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 6
		m.rings = 4
		a.mesh = m
		var mat := StandardMaterial3D.new()
		var g := _rng.randf_range(0.25, 0.45)
		mat.albedo_color = Color(g, g * 0.95, g * 0.9)
		mat.roughness = 1.0
		a.material_override = mat
		# Place in a shell around origin so the spawn point stays clear.
		a.position = _random_unit() * _rng.randf_range(40.0, 260.0)
		a.scale = Vector3(_rng.randf_range(0.7, 1.4), _rng.randf_range(0.7, 1.4), _rng.randf_range(0.7, 1.4))
		a.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		add_child(a)

func _random_unit() -> Vector3:
	var v := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn())
	if v.length() < 0.001:
		v = Vector3(0, 0, 1)
	return v.normalized()
