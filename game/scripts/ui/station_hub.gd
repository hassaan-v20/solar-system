extends Node3D
## A 3D station hub you fly around between raids (Roundtable-Hold style): visit
## kiosks for Contracts, the Ship Bay, the Armory, and the Launch Pad. Fly near a
## kiosk and press F to open it.

const KIOSKS := [
	{"type": "contracts", "name": "CONTRACT BOARD", "ang": 0.0,   "col": Color(0.4, 0.8, 1.0)},
	{"type": "ship",      "name": "SHIP BAY",       "ang": 90.0,  "col": Color(0.5, 1.0, 0.7)},
	{"type": "armory",    "name": "ARMORY",         "ang": 180.0, "col": Color(1.0, 0.6, 0.4)},
	{"type": "launch",    "name": "LAUNCH PAD",     "ang": 270.0, "col": Color(1.0, 0.85, 0.4)},
]
const RADIUS := 24.0

var _ship: ShipController
var _cam: ChaseCamera
var _near: Dictionary = {}
var _panel: CanvasLayer
var _prompt: Label
var _credits: Label

func _ready() -> void:
	InputSetup.register()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var vp := get_viewport()
	vp.use_taa = true
	vp.msaa_3d = Viewport.MSAA_4X

	SpaceEnv.add_suns(self)
	var we := WorldEnvironment.new()
	we.environment = SpaceEnv.make_environment()
	add_child(we)

	_build_platform()
	for k in KIOSKS:
		_build_kiosk(k)
	_build_ship()
	_cam = ChaseCamera.new()
	_cam.target_path = _ship.get_path()
	_cam.distance = 13.0
	_cam.height = 4.0
	add_child(_cam)
	_cam.current = true
	_build_hud()

func _process(delta: float) -> void:
	if is_instance_valid(_ship):
		# Soft tether so you don't drift off into deep space.
		var d := _ship.global_position.length()
		if d > 60.0:
			_ship.velocity -= _ship.global_position.normalized() * (d - 60.0) * 2.0 * delta
	if _prompt != null:
		_prompt.text = "[F]  %s" % _near.name if not _near.is_empty() and _panel == null else ""
	if _credits != null:
		_credits.text = "CREDITS  %d" % GameState.credits

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
	elif event.is_action_pressed("toggle_mouse"):
		if _panel != null:
			_close_panel()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact") and _panel == null and not _near.is_empty():
		_open_panel(_near)

# ── 3D dressing ────────────────────────────────────────────────────────────────
func _build_platform() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.16, 0.18, 0.22)
	floor_mat.metallic = 0.6
	floor_mat.roughness = 0.5
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 34.0
	cm.bottom_radius = 34.0
	cm.height = 1.0
	disc.mesh = cm
	disc.position = Vector3(0, -2.5, 0)
	disc.material_override = floor_mat
	add_child(disc)
	# Glowing central column / hologram.
	var col := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 2.5
	cc.bottom_radius = 3.5
	cc.height = 8.0
	col.mesh = cc
	col.position = Vector3(0, 2.0, 0)
	col.material_override = _glow(Color(0.4, 0.85, 1.0), 2.5)
	add_child(col)
	# Warm interior light.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.7)
	lamp.light_energy = 4.0
	lamp.omni_range = 70.0
	lamp.position = Vector3(0, 10, 0)
	add_child(lamp)

func _build_kiosk(k: Dictionary) -> void:
	var root := Node3D.new()
	add_child(root)
	var a := deg_to_rad(k.ang)
	root.position = Vector3(cos(a) * RADIUS, 0, sin(a) * RADIUS)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.27)
	mat.metallic = 0.6
	mat.roughness = 0.4
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(4.0, 2.0, 1.4)
	base.mesh = bb
	base.material_override = mat
	root.add_child(base)
	# Glowing screen.
	var screen := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(3.0, 1.6, 0.15)
	screen.mesh = sb
	screen.position = Vector3(0, 1.6, 0.7)
	screen.rotation_degrees = Vector3(-18, 0, 0)
	screen.material_override = _glow(k.col, 2.2)
	root.add_child(screen)
	# Floating label.
	var lbl := Label3D.new()
	lbl.text = k.name
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 64
	lbl.pixel_size = 0.012
	lbl.modulate = k.col
	lbl.position = Vector3(0, 3.4, 0)
	root.add_child(lbl)
	# Kiosk light.
	var l := OmniLight3D.new()
	l.light_color = k.col
	l.light_energy = 3.0
	l.omni_range = 16.0
	l.position = Vector3(0, 2.5, 1.5)
	root.add_child(l)
	# Interaction zone.
	var zone := Area3D.new()
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 8.0
	cs.shape = sp
	zone.add_child(cs)
	root.add_child(zone)
	zone.body_entered.connect(func(b): if b.is_in_group("player"): _near = k)
	zone.body_exited.connect(func(b): if b.is_in_group("player") and _near == k: _near = {})

func _build_ship() -> void:
	_ship = ShipController.new()
	var def := load("res://data/ships/wayfarer.tres")
	if def is ShipDef:
		var d := def.duplicate()
		d.max_speed = 16.0
		d.boost_speed = 28.0
		d.acceleration = 16.0
		_ship.ship_def = d
	# Compact modelled hull.
	var hullmat := StandardMaterial3D.new()
	hullmat.albedo_color = Color(0.55, 0.6, 0.7)
	hullmat.metallic = 0.8
	hullmat.roughness = 0.3
	var comb := CSGCombiner3D.new()
	var fus := CSGCylinder3D.new()
	fus.radius = 0.55
	fus.height = 3.0
	fus.sides = 18
	fus.smooth_faces = true
	fus.rotation_degrees = Vector3(90, 0, 0)
	fus.material = hullmat
	comb.add_child(fus)
	var nose := CSGSphere3D.new()
	nose.radius = 0.55
	nose.smooth_faces = true
	nose.scale = Vector3(0.85, 0.85, 2.6)
	nose.position = Vector3(0, 0, -2.0)
	nose.material = hullmat
	comb.add_child(nose)
	for sx in [-1.4, 1.4]:
		var wing := CSGBox3D.new()
		wing.size = Vector3(2.7, 0.14, 1.3)
		wing.position = Vector3(sx, 0, 0.5)
		wing.rotation_degrees = Vector3(0, 18 * signf(sx), 6 * signf(sx))
		wing.material = hullmat
		comb.add_child(wing)
	_ship.add_child(comb)
	var engine := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.4
	es.height = 0.8
	engine.mesh = es
	engine.position = Vector3(0, 0, 2.2)
	engine.scale = Vector3(1.6, 0.7, 1.4)
	engine.material_override = _glow(Color(0.45, 0.8, 1.0), 4.0)
	_ship.add_child(engine)
	var cshape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.6, 0.7, 3.6)
	cshape.shape = bs
	_ship.add_child(cshape)
	add_child(_ship)
	_ship.position = Vector3(0, 0, 12)

func _glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

# ── HUD + panels ──────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	var title := Label.new()
	title.text = "STATION HUB"
	title.position = Vector2(36, 26)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	root.add_child(title)
	_credits = Label.new()
	_credits.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_credits.offset_left = -340
	_credits.offset_top = 30
	_credits.offset_right = -36
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_credits.add_theme_font_size_override("font_size", 24)
	_credits.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	root.add_child(_credits)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150
	_prompt.offset_left = -200
	_prompt.offset_right = 200
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	root.add_child(_prompt)
	var hint := Label.new()
	hint.text = "WASD/Q-E fly   ·   mouse steer   ·   F interact   ·   Esc free mouse"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -34
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	root.add_child(hint)

func _open_panel(k: Dictionary) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ship.set_physics_process(false)
	_panel = CanvasLayer.new()
	add_child(_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	_panel.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(560, 0)
	_panel.add_child(box)
	var head := Label.new()
	head.text = k.name
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", k.col)
	box.add_child(head)
	box.add_child(_spacer(8))

	match k.type:
		"contracts":
			_panel_contracts(box)
		"ship":
			_panel_upgrades(box, ["hull", "shield", "engine"])
		"armory":
			_panel_upgrades(box, ["weapon", "missile"])
		"launch":
			_panel_launch(box)

	box.add_child(_spacer(10))
	var close := _btn("Close  (Esc)")
	close.pressed.connect(_close_panel)
	box.add_child(close)

func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_ship.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _panel_contracts(box: VBoxContainer) -> void:
	for path in GameState.MISSIONS:
		var def = load(path)
		var b := _btn("%s    ·    %d cr" % [def.display_name, def.reward])
		b.toggle_mode = true
		b.button_pressed = (path == GameState.selected_mission)
		b.pressed.connect(func():
			GameState.selected_mission = path
			_close_panel())
		box.add_child(b)

func _panel_upgrades(box: VBoxContainer, keys: Array) -> void:
	for key in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(330, 0)
		name_lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(name_lbl)
		var buy := _btn("")
		buy.custom_minimum_size = Vector2(180, 44)
		row.add_child(buy)
		box.add_child(row)
		var refresh := func():
			name_lbl.text = "%s   Lv %d" % [GameState.UPGRADES[key].name, GameState.upgrades[key]]
			var c := GameState.cost(key)
			buy.text = "Buy  %d cr" % c
			buy.disabled = GameState.credits < c
		buy.pressed.connect(func():
			GameState.buy(key)
			refresh.call())
		refresh.call()

func _panel_launch(box: VBoxContainer) -> void:
	var def = load(GameState.selected_mission)
	var info := Label.new()
	info.text = "Contract:  %s\nReward:  %d cr" % [def.display_name, def.reward]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	box.add_child(info)
	box.add_child(_spacer(8))
	var go := _btn("LAUNCH RAID")
	go.custom_minimum_size = Vector2(0, 56)
	go.add_theme_font_size_override("font_size", 26)
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/raid/ghost_station_raid.tscn"))
	box.add_child(go)

func _btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
