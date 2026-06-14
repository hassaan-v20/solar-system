extends Node3D
## Kestrel Station as a flyable hub (the game's main scene). You pilot your ship
## around the SOLID station and dock at physical service zones — fly in, press F to
## open that panel: Departure (launch raid + co-op), Upgrades, Repair, Ship Bay.
## Reuses the raid's flight/camera/collision; peaceful (no combat, no HUD).

const STATION_MODEL_PATH := "res://assets/models/station/kestrel_station.glb"
const STATION_TARGET_SIZE := 240.0

const SHIP_MODEL_PATH := "res://assets/models/ship/spaceship_ezno.glb"
const SHIP_MODEL_SCALE := 0.22
const SHIP_MODEL_EULER := Vector3(0, 180, 0)
const SHIP_MODEL_BOUNDS := Vector3(24.366, 5.592, 17.345)
const SHIP_MODEL_CENTER := Vector3(0.0, -1.346, -2.524)

const LAYER_ENVIRONMENT := 1
const LAYER_PLAYER_SHIP := 2
const PANEL_SCRIPT := "res://scripts/ui/lobby_panel.gd"

# Service docks placed around the station (angle in degrees around +Y, plus height).
const DOCKS := [
	{"id": "launch", "label": "DEPARTURE", "color": Color(0.4, 1.0, 0.6), "angle": 0.0, "height": 0.0},
	{"id": "upgrades", "label": "UPGRADES", "color": Color(0.4, 0.7, 1.0), "angle": 90.0, "height": 14.0},
	{"id": "repair", "label": "REPAIR BAY", "color": Color(1.0, 0.8, 0.35), "angle": 195.0, "height": 0.0},
	{"id": "ship", "label": "SHIP BAY", "color": Color(0.72, 0.6, 0.92), "angle": 285.0, "height": 14.0},
]

var _ship: ShipController
var _panel: Node          # LobbyPanel (loaded by path)
var _prompt: Label
var _want_capture := true
var _active_dock := ""
var _station_radius := 120.0

func _ready() -> void:
	InputSetup.configure()
	_set_capture(true)
	_build_environment()
	_build_lights()
	_build_station()
	_build_backdrops()
	_build_ship()
	_build_camera()
	_build_ui()
	_build_docks()

func _process(_delta: float) -> void:
	# Hold mouse capture for flight, unless a panel is open (Settings.input_locked).
	if _want_capture and not Settings.input_locked and get_window().has_focus() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
	elif event.is_action_pressed("toggle_fullscreen"):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_set_capture(true)
	elif event.is_action_pressed("dock") and _active_dock != "" and not _panel.is_open():
		_open_panel(_active_dock)

# ── world ─────────────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/textures/sky/nebula_lobby_blue.hdr")   # calm "home" blue nebula
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.20)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Gentle cinematic grade: a touch more contrast + saturation.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.18
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 38, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.97, 0.92)
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(18, -140, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.5, 0.7, 1.0)
	add_child(rim)

func _build_station() -> void:
	var scene := load(STATION_MODEL_PATH)
	if not (scene is PackedScene):
		push_warning("lobby station not imported: %s" % STATION_MODEL_PATH)
		return
	var pivot := Node3D.new()
	var model := (scene as PackedScene).instantiate()
	pivot.add_child(model)
	add_child(pivot)
	var ab := ModelUtil.combined_aabb(pivot, model)
	if ab.size.length() > 0.001:
		model.position = -ab.get_center()
		var max_dim: float = maxf(maxf(ab.size.x, ab.size.y), ab.size.z)
		pivot.scale = Vector3.ONE * (STATION_TARGET_SIZE / max_dim)
		_station_radius = STATION_TARGET_SIZE * 0.5
	# Make it solid so you fly around it (trimesh follows the hull; openings stay open).
	ModelUtil.add_trimesh_collision(model, LAYER_ENVIRONMENT)

## Earth as a big planet beyond the station — cinematic depth for the hub. The
## starfield/Milky Way comes from the skybox panorama (_build_environment).
func _build_backdrops() -> void:
	var earth: Node3D = (load("res://scripts/core/planet_backdrop.gd") as GDScript).new()
	earth.model_1k = "res://assets/models/planets/planet_earth_1k.glb"
	earth.model_4k = "res://assets/models/planets/planet_earth_4k.glb"
	earth.radius = 420.0
	earth.viewer = Vector3(0, 0, _station_radius + 150.0)   # the ship's spawn point
	earth.position = Vector3(700, 150, -1100)
	add_child(earth)

func _build_ship() -> void:
	_ship = ShipController.new()
	var base := load("res://data/ships/wayfarer.tres")
	_ship.ship_def = UpgradeSystem.outfit(base, PlayerProfile.owned_upgrades)

	var model := ModelUtil.spawn(SHIP_MODEL_PATH, SHIP_MODEL_SCALE, SHIP_MODEL_EULER, SHIP_MODEL_CENTER)
	if model != null:
		_ship.add_child(model)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var ext := (Basis.from_euler(SHIP_MODEL_EULER * (PI / 180.0)) * SHIP_MODEL_BOUNDS).abs()
	shape.size = ext * SHIP_MODEL_SCALE * 0.9
	col.shape = shape
	_ship.add_child(col)
	_ship.collision_layer = LAYER_PLAYER_SHIP
	_ship.collision_mask = LAYER_ENVIRONMENT

	var fx := ShipFX.new()
	fx.engine_color = Color(0.55, 0.62, 0.72).lerp(Color(1.0, 0.5, 0.2), 0.6)
	_ship.add_child(fx)

	add_child(_ship)
	_ship.global_position = Vector3(0, 0, _station_radius + 150.0)   # out in front of the station
	_ship.look_at(Vector3.ZERO, Vector3.UP)                          # nose toward the station

	# The lobby ship is always the LOCAL player's (the lobby isn't a shared scene),
	# so it must own authority — otherwise a joined client's ship would freeze (the
	# ShipController authority gate). Re-assert it once we know our peer id.
	_ship.set_multiplayer_authority(multiplayer.get_unique_id())
	Net.joined.connect(func() -> void: _ship.set_multiplayer_authority(multiplayer.get_unique_id()))

func _build_camera() -> void:
	var cam := ChaseCamera.new()
	cam.target_path = _ship.get_path()
	add_child(cam)
	cam.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "KESTREL STATION"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1, 1, 1, 0.7)
	layer.add_child(title)

	var hint := Label.new()
	hint.text = "Fly to a bay and press F   ·   W/S thrust   mouse aim   Q/E strafe   Shift boost   Ctrl brake   F8 quit"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.45)
	layer.add_child(hint)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -96
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(0.6, 1.0, 0.8)
	_prompt.visible = false
	layer.add_child(_prompt)

	_panel = (load(PANEL_SCRIPT) as GDScript).new()
	add_child(_panel)
	_panel.closed.connect(_on_panel_closed)

func _build_docks() -> void:
	for d in DOCKS:
		var ang := deg_to_rad(float(d["angle"]))
		var r := _station_radius + 55.0
		var pos := Vector3(sin(ang) * r, float(d["height"]), cos(ang) * r)

		var zone := ShipZone.new()
		zone.radius = 32.0
		zone.marker_radius = 13.0
		zone.marker_color = d["color"]
		zone.position = pos
		add_child(zone)
		zone.ship_entered.connect(_on_dock_entered.bind(d))
		zone.ship_exited.connect(_on_dock_exited.bind(String(d["id"])))

		var label := Label3D.new()
		label.text = d["label"]
		label.position = pos + Vector3(0, 20, 0)
		label.font_size = 64
		label.pixel_size = 0.06
		label.modulate = d["color"]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = false
		add_child(label)

# ── docking ───────────────────────────────────────────────────────────────────
func _on_dock_entered(dock: Dictionary) -> void:
	_active_dock = String(dock["id"])
	_prompt.text = "PRESS F  —  %s" % dock["label"]
	if not _panel.is_open():
		_prompt.visible = true

func _on_dock_exited(id: String) -> void:
	if _active_dock == id:
		_active_dock = ""
		_prompt.visible = false

func _open_panel(service: String) -> void:
	Settings.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prompt.visible = false
	_panel.open(service)

func _on_panel_closed() -> void:
	Settings.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _active_dock != "":
		_prompt.visible = true

func _set_capture(on: bool) -> void:
	_want_capture = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
