extends Node3D
## Cinematic main menu: a live 3D space scene (nebula sky, suns, drifting
## asteroids, a slowly turning hero ship) with a game-style menu overlay.

var _ship: Node3D
var _cam: Camera3D
var _rocks: Array = []
var _t: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport()
	vp.use_taa = true
	vp.msaa_3d = Viewport.MSAA_4X

	SpaceEnv.add_suns(self)
	var we := WorldEnvironment.new()
	we.environment = SpaceEnv.make_environment()
	add_child(we)

	_ship = _build_ship()
	add_child(_ship)
	_build_asteroids()

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.position = Vector3(0, 2.4, 11)
	_cam.look_at(Vector3.ZERO, Vector3.UP)
	_cam.current = true

	_build_ui()

func _process(delta: float) -> void:
	_t += delta
	if _ship != null:
		_ship.rotation.y = _t * 0.35
		_ship.position.y = sin(_t * 0.7) * 0.35
	for r in _rocks:
		r.node.rotate(r.axis, r.speed * delta)
	if _cam != null:
		_cam.position = Vector3(sin(_t * 0.12) * 2.2, 2.4 + sin(_t * 0.2) * 0.3, 11.0)
		_cam.look_at(Vector3.ZERO, Vector3.UP)

# ── 3D dressing ────────────────────────────────────────────────────────────────
func _build_ship() -> Node3D:
	var root := Node3D.new()
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.55, 0.60, 0.70)
	hull.metallic = 0.8
	hull.roughness = 0.3
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.3, 0.55, 0.85)
	accent.metallic = 0.6
	accent.roughness = 0.4

	var comb := CSGCombiner3D.new()
	var fus := CSGCylinder3D.new()
	fus.radius = 0.55
	fus.height = 3.0
	fus.sides = 20
	fus.smooth_faces = true
	fus.rotation_degrees = Vector3(90, 0, 0)
	fus.material = hull
	comb.add_child(fus)
	var nose := CSGSphere3D.new()
	nose.radius = 0.55
	nose.radial_segments = 20
	nose.rings = 10
	nose.smooth_faces = true
	nose.scale = Vector3(0.85, 0.85, 2.6)
	nose.position = Vector3(0, 0, -2.0)
	nose.material = hull
	comb.add_child(nose)
	for sx in [-1.4, 1.4]:
		var wing := CSGBox3D.new()
		wing.size = Vector3(2.7, 0.14, 1.3)
		wing.position = Vector3(sx, 0, 0.5)
		wing.rotation_degrees = Vector3(0, 18 * signf(sx), 6 * signf(sx))
		wing.material = hull
		comb.add_child(wing)
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
	root.add_child(comb)

	var cockpit := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.5, 0.32, 1.1)
	cockpit.mesh = cb
	cockpit.position = Vector3(0, 0.4, -0.7)
	cockpit.material_override = _emit(Color(0.4, 0.8, 1.0), 2.2)
	root.add_child(cockpit)

	var engine := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.4
	es.height = 0.8
	engine.mesh = es
	engine.position = Vector3(0, 0, 2.2)
	engine.scale = Vector3(1.6, 0.7, 1.4)
	engine.material_override = _emit(Color(0.45, 0.8, 1.0), 4.0)
	root.add_child(engine)
	return root

func _build_asteroids() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.28, 0.25)
	mat.roughness = 1.0
	for i in 16:
		var a := MeshInstance3D.new()
		var m := SphereMesh.new()
		var r := rng.randf_range(0.6, 2.2)
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 8
		m.rings = 5
		a.mesh = m
		a.material_override = mat
		var dir := Vector3(rng.randfn(), rng.randfn() * 0.5, rng.randfn()).normalized()
		a.position = dir * rng.randf_range(10.0, 34.0)
		a.scale = Vector3(rng.randf_range(0.7, 1.4), rng.randf_range(0.7, 1.3), rng.randf_range(0.7, 1.4))
		add_child(a)
		_rocks.append({"node": a, "axis": dir, "speed": rng.randf_range(0.1, 0.5)})

func _emit(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

# ── menu overlay ──────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)

	var title := Label.new()
	title.text = "STELLAR"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 90
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color(0.8, 0.93, 1.0))
	root.add_child(title)

	var sub := Label.new()
	sub.text = "C O - O P   S P A C E   R A I D   E X T R A C T I O N"
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 220
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.55, 0.7, 0.9))
	root.add_child(sub)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_top = 40
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)

	var play := _button("LAUNCH")
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/station.tscn"))
	box.add_child(play)
	var quit := _button("QUIT")
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	play.grab_focus()  # so a controller / keyboard can drive the menu immediately

	var info := Label.new()
	info.text = "Credits %d    ·    Raids %d (won %d)" % [GameState.credits, GameState.stats.raids, GameState.stats.wins]
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_top = -48
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.5, 0.6, 0.75))
	root.add_child(info)

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_size_override("font_size", 24)
	return b
