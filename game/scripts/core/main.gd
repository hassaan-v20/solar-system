extends Node3D
## Ghost Station — Milestone 2 bootstrap.
## Builds a flyable, *fightable* sector in code: starfield sky, asteroid field,
## the player ship + laser, and waves of enemy drones. Real scenes/assets get
## split out in later milestones.

const ASTEROID_COUNT := 120

var _rng := RandomNumberGenerator.new()
var _ship: ShipController
var _hud: ShipHUD
var _engine_mat: StandardMaterial3D
var _asteroids: Array = []        # [{node, axis, speed}]
var _enemies: int = 0
var _kills: int = 0
var _score: int = 0
var _wave: int = 0

func _ready() -> void:
	_rng.randomize()
	_setup_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_environment()
	_ship = _build_ship()
	_build_weapon(_ship)
	_build_camera(_ship)
	_build_hud(_ship)
	_build_asteroids()
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	_spawn_wave()

func _process(delta: float) -> void:
	for a in _asteroids:
		a.node.rotate(a.axis, a.speed * delta)
	if _engine_mat != null and is_instance_valid(_ship):
		var f := clampf(_ship.get_speed() / _ship.ship_def.max_speed, 0.0, 1.0)
		_engine_mat.emission_energy_multiplier = 1.4 + f * 3.5 + (3.0 if _ship.is_boosting else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()

# ── input ─────────────────────────────────────────────────────────────────────
func _setup_input() -> void:
	var binds := {
		"thrust_forward": [KEY_W], "thrust_back": [KEY_S],
		"strafe_left": [KEY_Q], "strafe_right": [KEY_E],
		"roll_left": [KEY_A], "roll_right": [KEY_D],
		"boost": [KEY_SHIFT], "brake": [KEY_CTRL],
		"fire": [KEY_SPACE],
		"toggle_mouse": [KEY_ESCAPE], "quit_game": [KEY_F8],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Left mouse also fires.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mb)

# ── world ─────────────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.9)
	add_child(sun)

	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/space_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.03, 0.06)
	env.fog_density = 0.0014
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_ship() -> ShipController:
	var ship := ShipController.new()
	ship.name = "Wayfarer"
	var def := load("res://data/ships/wayfarer.tres")
	if def is ShipDef:
		ship.ship_def = def

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.2, 0.7, 3.4)
	body.mesh = box
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.58, 0.63, 0.72)
	hull_mat.metallic = 0.7
	hull_mat.roughness = 0.35
	body.material_override = hull_mat
	ship.add_child(body)

	var nose := MeshInstance3D.new()
	var nbox := BoxMesh.new()
	nbox.size = Vector3(0.5, 0.5, 1.0)
	nose.mesh = nbox
	nose.position = Vector3(0, 0, -2.0)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.4, 0.7, 1.0)
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(0.3, 0.7, 1.0)
	nose_mat.emission_energy_multiplier = 2.5
	nose.material_override = nose_mat
	ship.add_child(nose)

	# Engine glow at the back; pulses with thrust/boost (driven in _process).
	var engine := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.45
	em.height = 0.9
	engine.mesh = em
	engine.position = Vector3(0, 0, 1.9)
	engine.scale = Vector3(1.0, 0.7, 1.6)
	_engine_mat = StandardMaterial3D.new()
	_engine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_engine_mat.albedo_color = Color(0.5, 0.8, 1.0)
	_engine_mat.emission_enabled = true
	_engine_mat.emission = Color(0.4, 0.75, 1.0)
	_engine_mat.emission_energy_multiplier = 2.0
	engine.material_override = _engine_mat
	ship.add_child(engine)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.7, 3.4)
	col.shape = shape
	ship.add_child(col)

	add_child(ship)
	return ship

func _build_weapon(ship: ShipController) -> void:
	var w := WeaponController.new()
	var wd := load("res://data/weapons/laser_cannon_mk1.tres")
	if wd is WeaponDef:
		w.weapon_def = wd
	w.team = "player"
	w.poll_input = true
	w.bolt_color = Color(0.5, 0.9, 1.0)
	w.world = self
	ship.add_child(w)
	ship.set_meta("weapon", w)

func _build_camera(ship: ShipController) -> void:
	var cam := ChaseCamera.new()
	cam.target_path = ship.get_path()
	add_child(cam)
	cam.current = true

func _build_hud(ship: ShipController) -> void:
	_hud = ShipHUD.new()
	_hud.ship = ship
	_hud.weapon = ship.get_meta("weapon")
	add_child(_hud)

func _build_asteroids() -> void:
	for i in ASTEROID_COUNT:
		var a := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := _rng.randf_range(1.5, 6.0)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 7
		m.rings = 5
		a.mesh = m
		var mat := StandardMaterial3D.new()
		var g := _rng.randf_range(0.22, 0.42)
		mat.albedo_color = Color(g, g * 0.93, g * 0.86)
		mat.metallic = 0.1
		mat.roughness = 1.0
		a.material_override = mat
		a.position = _random_unit() * _rng.randf_range(45.0, 280.0)
		a.scale = Vector3(_rng.randf_range(0.7, 1.4), _rng.randf_range(0.7, 1.4), _rng.randf_range(0.7, 1.4))
		a.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		add_child(a)
		_asteroids.append({"node": a, "axis": _random_unit(), "speed": _rng.randf_range(0.05, 0.4)})

# ── combat / waves ─────────────────────────────────────────────────────────────
func _spawn_wave() -> void:
	_wave += 1
	var n := 2 + _wave
	for i in n:
		_spawn_drone()
	if _hud != null:
		_hud.set_combat(_kills, _enemies, _score, _wave)

func _spawn_drone() -> void:
	if not is_instance_valid(_ship):
		return
	var d := EnemyDroneAI.new()
	var ed := load("res://data/enemies/light_drone.tres")
	if ed is EnemyDef:
		d.enemy_def = ed
	d.world = self
	d.target = _ship
	d.destroyed.connect(_on_enemy_destroyed)
	add_child(d)
	d.global_position = _ship.global_position + _random_unit() * _rng.randf_range(130.0, 230.0)
	_enemies += 1

func _on_enemy_destroyed(score: int, _at: Vector3) -> void:
	_kills += 1
	_score += score
	_enemies -= 1
	if _hud != null:
		_hud.set_combat(_kills, _enemies, _score, _wave)
	if _enemies <= 0:
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(_ship) and not _ship.is_dead:
			_spawn_wave()

func _on_ship_destroyed() -> void:
	if _hud != null:
		_hud.show_destroyed()
	await get_tree().create_timer(3.0).timeout
	_respawn()

func _respawn() -> void:
	if not is_instance_valid(_ship):
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	_enemies = 0
	_ship.global_position = Vector3.ZERO
	_ship.velocity = Vector3.ZERO
	_ship.is_dead = false
	_ship.current_hull = _ship.ship_def.hull_max
	_ship.current_shield = _ship.ship_def.shield_max
	if _hud != null:
		_hud.hide_destroyed()
	_spawn_wave()

func _random_unit() -> Vector3:
	var v := Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn())
	if v.length() < 0.001:
		v = Vector3(0, 0, 1)
	return v.normalized()
