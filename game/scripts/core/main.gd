extends Node3D
## Ghost Station — Milestone 2 bootstrap.
## Builds a flyable, *fightable* sector in code: starfield sky, asteroid field,
## the player ship + laser, and waves of enemy drones. Real scenes/assets get
## split out in later milestones.

const ASTEROID_COUNT := 120

var _rng := RandomNumberGenerator.new()
var _ship: ShipController
var _hud: ShipHUD
var _cam: ChaseCamera
var _mission: MissionManager
var _engine_mat: StandardMaterial3D
var _asteroids: Array = []        # [{node, axis, speed}]
var _enemies: int = 0
var _kills: int = 0
var _score: int = 0
var _wave: int = 0

const MISSILE_MAX := 6
var _missiles: int = MISSILE_MAX
var _missile_cd: float = 0.0
var _missile_regen: float = 0.0

func _ready() -> void:
	_rng.randomize()
	var vp := get_viewport()
	vp.use_taa = true
	vp.msaa_3d = Viewport.MSAA_2X
	_setup_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_child(Sfx.new())
	var fx := Fx.new()
	fx.world = self
	add_child(fx)
	_build_environment()
	_ship = _build_ship()
	_build_weapon(_ship)
	_build_camera(_ship)
	_build_hud(_ship)
	_build_overlay()
	_build_asteroids()
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	_spawn_wave()
	_start_mission()

const MISSIONS := [
	"res://data/missions/ghost_station.tres",
	"res://data/missions/salvage_run.tres",
	"res://data/missions/last_stand.tres",
	"res://data/missions/bounty_hunt.tres",
	"res://data/missions/deep_core.tres",
]

func _start_mission() -> void:
	EventBus.mission_spawn.connect(_on_mission_spawn)
	EventBus.mission_state_changed.connect(_on_mission_state)
	_new_mission()

func _new_mission() -> void:
	for o in get_tree().get_nodes_in_group("objective"):
		o.queue_free()
	var def := load(MISSIONS[_rng.randi() % MISSIONS.size()])
	_mission = MissionManager.new()
	_mission.world = self
	_mission.ship = _ship
	_mission.mission_def = def
	add_child(_mission)
	_mission.begin()

func _on_mission_spawn(count: int, near: Vector3, _elite: bool) -> void:
	for i in count:
		_spawn_enemy(_pick_enemy(), near)

func _on_mission_state(state: String) -> void:
	if state == "complete" or state == "failed":
		await get_tree().create_timer(6.0).timeout
		if is_instance_valid(_mission):
			_mission.queue_free()
		_new_mission()

func _process(delta: float) -> void:
	for a in _asteroids:
		a.node.rotate(a.axis, a.speed * delta)
	if _engine_mat != null and is_instance_valid(_ship):
		var f := clampf(_ship.get_speed() / _ship.ship_def.max_speed, 0.0, 1.0)
		_engine_mat.emission_energy_multiplier = 1.4 + f * 3.5 + (3.0 if _ship.is_boosting else 0.0)
	_missile_cd = maxf(0.0, _missile_cd - delta)
	if _missiles < MISSILE_MAX:
		_missile_regen += delta
		if _missile_regen >= 3.5:
			_missile_regen = 0.0
			_missiles += 1
	if _hud != null:
		_hud.set_missiles(_missiles, MISSILE_MAX)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()
	elif event.is_action_pressed("fire_secondary"):
		_fire_missile()

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
	# Left mouse also fires the laser.
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", mb)
	# Secondary fire (homing missile): right mouse or F.
	if not InputMap.has_action("fire_secondary"):
		InputMap.add_action("fire_secondary")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("fire_secondary", rmb)
	var keyf := InputEventKey.new()
	keyf.physical_keycode = KEY_F
	InputMap.action_add_event("fire_secondary", keyf)

# ── world ─────────────────────────────────────────────────────────────────────
func _build_environment() -> void:
	# Three distant suns: each a visible bright star plus a directional light, so
	# the whole sector is well lit and easy to read while still feeling like space.
	_build_sun(Vector3(1.0, 0.45, 0.6), Color(1.0, 0.92, 0.78), 1.7, 30.0)    # warm key
	_build_sun(Vector3(-0.7, 0.25, -0.8), Color(0.55, 0.7, 1.0), 0.7, 22.0)   # cool fill
	_build_sun(Vector3(0.2, -0.55, 0.8), Color(1.0, 0.6, 0.7), 0.5, 18.0)     # pink rim

	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/space_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.25
	env.glow_strength = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.08)
	env.fog_density = 0.0011
	# Modern post-processing for a realistic look.
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.2
	env.ssr_enabled = true
	env.ssr_max_steps = 32
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.003
	env.volumetric_fog_emission = Color(0.05, 0.07, 0.14)
	env.volumetric_fog_emission_energy = 0.3
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.14
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_sun(dir: Vector3, col: Color, energy: float, radius: float) -> void:
	var d := dir.normalized()
	# Visible star far away.
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	star.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 8.0
	star.material_override = mat
	add_child(star)
	star.global_position = d * 1700.0
	# Directional light from that star.
	var dl := DirectionalLight3D.new()
	dl.light_color = col
	dl.light_energy = energy
	add_child(dl)
	if absf(d.dot(Vector3.UP)) < 0.98:
		dl.look_at(-d, Vector3.UP)

func _build_ship() -> ShipController:
	var ship := ShipController.new()
	ship.name = "Wayfarer"
	var def := load("res://data/ships/wayfarer.tres")
	if def is ShipDef:
		ship.ship_def = def

	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.55, 0.60, 0.70)
	hull.metallic = 0.75
	hull.roughness = 0.3
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.30, 0.55, 0.85)
	accent.metallic = 0.6
	accent.roughness = 0.4

	# Hull: a single rounded CSG body (smooth fuselage + nose + wings + tail + pods),
	# so the ship reads as a real modelled mesh rather than stacked boxes.
	var comb := CSGCombiner3D.new()
	var fus := CSGCylinder3D.new()
	fus.radius = 0.55
	fus.height = 3.0
	fus.sides = 18
	fus.smooth_faces = true
	fus.rotation_degrees = Vector3(90, 0, 0)
	fus.material = hull
	comb.add_child(fus)
	var nosecap := CSGSphere3D.new()
	nosecap.radius = 0.55
	nosecap.radial_segments = 18
	nosecap.rings = 9
	nosecap.smooth_faces = true
	nosecap.scale = Vector3(0.85, 0.85, 2.6)
	nosecap.position = Vector3(0, 0, -2.0)
	nosecap.material = hull
	comb.add_child(nosecap)
	var tailcap := CSGSphere3D.new()
	tailcap.radius = 0.55
	tailcap.radial_segments = 16
	tailcap.rings = 8
	tailcap.smooth_faces = true
	tailcap.scale = Vector3(1.0, 1.0, 1.3)
	tailcap.position = Vector3(0, 0, 1.4)
	tailcap.material = hull
	comb.add_child(tailcap)
	var wl := CSGBox3D.new()
	wl.size = Vector3(2.7, 0.14, 1.3)
	wl.position = Vector3(-1.4, 0, 0.5)
	wl.rotation_degrees = Vector3(0, -18, -6)
	wl.material = hull
	comb.add_child(wl)
	var wr := CSGBox3D.new()
	wr.size = Vector3(2.7, 0.14, 1.3)
	wr.position = Vector3(1.4, 0, 0.5)
	wr.rotation_degrees = Vector3(0, 18, 6)
	wr.material = hull
	comb.add_child(wr)
	var finbox := CSGBox3D.new()
	finbox.size = Vector3(0.14, 1.0, 1.0)
	finbox.position = Vector3(0, 0.55, 1.3)
	finbox.rotation_degrees = Vector3(-18, 0, 0)
	finbox.material = hull
	comb.add_child(finbox)
	for sx in [-0.62, 0.62]:
		var pod := CSGCylinder3D.new()
		pod.radius = 0.28
		pod.height = 1.6
		pod.sides = 14
		pod.smooth_faces = true
		pod.rotation_degrees = Vector3(90, 0, 0)
		pod.position = Vector3(sx, 0, 1.4)
		pod.material = accent
		comb.add_child(pod)
	ship.add_child(comb)

	# Cockpit canopy (glowing accent).
	var cockpit := BoxMesh.new()
	cockpit.size = Vector3(0.5, 0.32, 1.1)
	var cp_mat := StandardMaterial3D.new()
	cp_mat.albedo_color = Color(0.4, 0.75, 1.0)
	cp_mat.emission_enabled = true
	cp_mat.emission = Color(0.4, 0.8, 1.0)
	cp_mat.emission_energy_multiplier = 2.0
	_part(ship, cockpit, Vector3(0, 0.4, -0.7), Vector3.ZERO, cp_mat)

	# Detail: dark belly, dorsal antenna, under-wing hardpoints, wingtip nav lights.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.20, 0.24)
	dark.metallic = 0.5
	dark.roughness = 0.6
	var belly := BoxMesh.new()
	belly.size = Vector3(0.7, 0.22, 1.8)
	_part(ship, belly, Vector3(0, -0.32, 0.2), Vector3.ZERO, dark)
	var ant := BoxMesh.new()
	ant.size = Vector3(0.06, 0.7, 0.06)
	_part(ship, ant, Vector3(0, 0.7, 0.9), Vector3(8, 0, 0), dark)
	var hp := BoxMesh.new()
	hp.size = Vector3(0.22, 0.22, 0.9)
	_part(ship, hp, Vector3(-1.7, -0.18, 0.5), Vector3.ZERO, dark)
	_part(ship, hp, Vector3(1.7, -0.18, 0.5), Vector3.ZERO, dark)
	var navmesh := SphereMesh.new()
	navmesh.radius = 0.12
	navmesh.height = 0.24
	_part(ship, navmesh, Vector3(-2.45, 0.05, 0.7), Vector3.ZERO, _emit_mat(Color(1.0, 0.2, 0.2)))
	_part(ship, navmesh, Vector3(2.45, 0.05, 0.7), Vector3.ZERO, _emit_mat(Color(0.2, 1.0, 0.3)))

	# Engine glow at the back; pulses with thrust/boost (driven in _process).
	var engine := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.4
	em.height = 0.8
	engine.mesh = em
	engine.position = Vector3(0, 0, 2.2)
	engine.scale = Vector3(1.6, 0.7, 1.4)
	_engine_mat = StandardMaterial3D.new()
	_engine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_engine_mat.albedo_color = Color(0.5, 0.8, 1.0)
	_engine_mat.emission_enabled = true
	_engine_mat.emission = Color(0.4, 0.75, 1.0)
	_engine_mat.emission_energy_multiplier = 2.0
	engine.material_override = _engine_mat
	ship.add_child(engine)
	_build_engine_trail(ship)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 0.7, 3.6)
	col.shape = shape
	ship.add_child(col)

	add_child(ship)
	return ship

func _build_engine_trail(ship: Node3D) -> void:
	var ps := GPUParticles3D.new()
	ps.amount = 48
	ps.lifetime = 0.55
	ps.position = Vector3(0, 0, 2.3)
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.direction = Vector3(0, 0, 1)          # local +z = behind the ship
	pm.spread = 7.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 17.0
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.9, 1.0, 1.0))
	grad.set_color(1, Color(0.2, 0.4, 1.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	ps.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh.radial_segments = 6
	mesh.rings = 4
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.vertex_color_use_as_albedo = true
	mm.albedo_color = Color(1, 1, 1, 1)
	mesh.material = mm
	ps.draw_pass_1 = mesh
	ps.emitting = true
	ship.add_child(ps)

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)

func _emit_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	return m

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
	_cam = ChaseCamera.new()
	_cam.target_path = ship.get_path()
	add_child(_cam)
	_cam.current = true

func _build_hud(ship: ShipController) -> void:
	_hud = ShipHUD.new()
	_hud.ship = ship
	_hud.weapon = ship.get_meta("weapon")
	add_child(_hud)

func _build_overlay() -> void:
	var ov := CombatOverlay.new()
	ov.camera = _cam
	ov.ship = _ship
	_hud.add_child(ov)

func _fire_missile() -> void:
	if _missiles <= 0 or _missile_cd > 0.0 or not is_instance_valid(_ship) or _ship.is_dead:
		return
	_missiles -= 1
	_missile_cd = 0.35
	var p := Projectile.new()
	p.team = "player"
	p.homing = true
	p.damage = 130.0
	p.speed = 130.0
	p.turn_rate = 3.2
	p.lifetime = 5.0
	p.color = Color(1.0, 0.6, 0.25)
	p.direction = -_ship.global_transform.basis.z
	add_child(p)
	p.global_position = _ship.global_position + p.direction * 3.0
	EventBus.shot_fired.emit("missile")

func _build_asteroids() -> void:
	var rock := _rock_material()
	for i in ASTEROID_COUNT:
		var a := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := _rng.randf_range(1.5, 6.0)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 18
		m.rings = 12
		a.mesh = m
		a.material_override = rock
		a.position = _random_unit() * _rng.randf_range(45.0, 280.0)
		# Irregular, lumpy silhouettes.
		a.scale = Vector3(_rng.randf_range(0.6, 1.6), _rng.randf_range(0.6, 1.5), _rng.randf_range(0.6, 1.6))
		a.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		add_child(a)
		_asteroids.append({"node": a, "axis": _random_unit(), "speed": _rng.randf_range(0.05, 0.35)})

func _rock_material() -> StandardMaterial3D:
	# Procedural PBR rock: noise albedo mottling + a noise normal map, mapped in
	# world space (triplanar) so every asteroid samples a different patch — varied
	# craggy surfaces from a single shared material, no UVs or art files needed.
	var an := FastNoiseLite.new()
	an.noise_type = FastNoiseLite.TYPE_SIMPLEX
	an.frequency = 0.9
	an.fractal_octaves = 5
	var alb := NoiseTexture2D.new()
	alb.width = 256
	alb.height = 256
	alb.seamless = true
	alb.noise = an

	var nn := FastNoiseLite.new()
	nn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nn.frequency = 1.6
	nn.fractal_octaves = 4
	var nrm := NoiseTexture2D.new()
	nrm.width = 256
	nrm.height = 256
	nrm.seamless = true
	nrm.as_normal_map = true
	nrm.bump_strength = 6.0
	nrm.noise = nn

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.46, 0.41, 0.36)
	m.albedo_texture = alb
	m.normal_enabled = true
	m.normal_texture = nrm
	m.normal_scale = 1.6
	m.roughness = 0.95
	m.metallic = 0.02
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.06, 0.06, 0.06)
	return m

# ── combat / waves ─────────────────────────────────────────────────────────────
func _spawn_wave() -> void:
	_wave += 1
	var is_boss := _wave % 5 == 0
	EventBus.wave_started.emit(_wave, is_boss)
	if is_boss:
		_spawn_enemy("res://data/enemies/boss.tres")
		for i in 2:
			_spawn_enemy("res://data/enemies/light_drone.tres")
	else:
		var n := 2 + _wave
		for i in n:
			_spawn_enemy(_pick_enemy())
	if _hud != null:
		_hud.set_combat(_kills, _enemies, _score, _wave)

func _pick_enemy() -> String:
	var r := _rng.randf()
	if _wave >= 3 and r < 0.22:
		return "res://data/enemies/gunship.tres"
	if _wave >= 2 and r < 0.50:
		return "res://data/enemies/interceptor.tres"
	return "res://data/enemies/light_drone.tres"

func _spawn_enemy(path: String, center: Vector3 = Vector3.INF) -> void:
	if not is_instance_valid(_ship):
		return
	var c := center
	if c == Vector3.INF:
		c = _ship.global_position
	var d := EnemyDroneAI.new()
	var ed := load(path)
	if ed is EnemyDef:
		d.enemy_def = ed
	d.world = self
	d.target = _ship
	d.destroyed.connect(_on_enemy_destroyed)
	add_child(d)
	d.global_position = c + _random_unit() * _rng.randf_range(120.0, 230.0)
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
