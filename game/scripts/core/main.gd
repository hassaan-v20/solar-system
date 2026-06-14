extends Node3D
## Ghost Station — Milestone 1 bootstrap.
## Builds a flyable sector entirely in code (placeholder primitives) so the slice
## runs before any art exists. Real scenes/assets get split out in later
## milestones. Goal of M1 (GDD §27): "flying around feels acceptable."

const ASTEROID_COUNT := 140

# Imported ship model (replaces the placeholder boxes). The GLB is Y-up with its
# length along Z and nose toward -Z (Godot's forward), so it should need no
# rotation. Tweak SCALE for size; set EULER to Vector3(0, 180, 0) if it ever
# imports facing backward. BOUNDS is the model's local size (from the GLB) and
# drives the hitbox so collision tracks what you see.
const SHIP_MODEL_PATH := "res://assets/models/ship/spaceship_ezno.glb"
const SHIP_MODEL_SCALE := 0.22
# Nose is +Z (confirmed: the Thruster meshes sit at the -Z end), so a 180° yaw
# turns it to face Godot's forward (-Z).
const SHIP_MODEL_EULER := Vector3(0, 180, 0)
const SHIP_MODEL_BOUNDS := Vector3(24.366, 5.592, 17.345)   # world size from the GLB
const SHIP_MODEL_CENTER := Vector3(0.0, -1.346, -2.524)     # bbox-center offset to cancel

# Imported station model (replaces the placeholder spine + boxes). ~18.8u in the
# GLB; scaled up to roughly fill the dock zone (radius 26). Recentered like the ship.
const STATION_MODEL_PATH := "res://assets/models/station/spacestation_7.glb"
const STATION_MODEL_SCALE := 25.0   # a massive derelict (~470u); pushed back to 500u so it clears spawn
const STATION_MODEL_EULER := Vector3(0, 0, 0)
const STATION_MODEL_CENTER := Vector3(0.319, -1.672, 1.753)

# Asteroid rocks (3 low-poly meshes in the GLB) instanced across the field.
const ASTEROID_MODEL_PATH := "res://assets/models/asteroids/asteroids_andromeda.glb"

# Salvage crates — the loot you grab in the risk-greed loop.
const SALVAGE_MODEL_PATH := "res://assets/models/salvage/scifi_crates.glb"
const SALVAGE_MODEL_SCALE := 7.0
const SALVAGE_MODEL_CENTER := Vector3(0.0, 0.03, -0.013)
const SALVAGE_COUNT := 14

# Data Core objective, placed glowing at the station's heart (the thing you hack out).
const DATACORE_MODEL_PATH := "res://assets/models/objective/data_core_rack.glb"
const DATACORE_MODEL_SCALE := 9.0
const DATACORE_MODEL_CENTER := Vector3(0.0, 1.157, 0.0)

# Physics collision layers (1-based bit values). Friend/foe for weapons is decided
# entirely by these masks, so projectiles need no owner tracking (see projectile.gd).
const LAYER_ENVIRONMENT := 1   # asteroids / debris
const LAYER_PLAYER_SHIP := 2
const LAYER_ENEMY := 4

const RESULTS_SCENE := "res://scenes/station/results_screen.tscn"
const RESULTS_DELAY := 2.5      # let the end-of-mission overlay / explosion read
const DRONE_DEF_PATH := "res://data/enemies/light_drone.tres"
const COMBAT_NET_SCRIPT := "res://scripts/net/combat_net.gd"

# Hull tints per player slot so co-op ships are distinguishable.
const PEER_HULL_COLORS := [
	Color(0.55, 0.62, 0.72),   # slot 0 (host) — steel
	Color(0.80, 0.45, 0.25),   # slot 1 — rust
	Color(0.45, 0.70, 0.45),   # slot 2 — green
	Color(0.65, 0.50, 0.75),   # slot 3 — violet
]

var _rng := RandomNumberGenerator.new()
var _want_capture := true
var _ship: ShipController
var _camera: ChaseCamera
var _mission_def: MissionDef
var _drones_killed: int = 0
var _run_finished: bool = false
var _spawner: MultiplayerSpawner
var _enemy_spawner: MultiplayerSpawner   # co-op: host spawns drones, replicated to all
var _coop_ships: Array = []              # the player ships (host-side, for drone targeting)

func _ready() -> void:
	_setup_input()
	# Use Godot's own fullscreen (a borderless window), NOT macOS native
	# fullscreen (the green button) — native fullscreen opens a separate macOS
	# Space where mouse capture / relative steering breaks.
	_apply_fullscreen(true)
	_set_capture(true)
	_seed_rng()
	# Shared, deterministic sector (built identically on every peer from the seed).
	_build_environment()
	_build_planet()
	_build_asteroids()
	if Net.active:
		_setup_coop()
	else:
		_build_solo()

## Host-authoritative projectile layer (works in solo too; WeaponController finds it
## via the "combat_net" group). One per combat scene.
func _build_combat_net() -> void:
	add_child((load(COMBAT_NET_SCRIPT) as GDScript).new())

## Single-player: own ship + camera + HUD + the full Ghost Station mission.
func _build_solo() -> void:
	_build_combat_net()
	_ship = _build_ship()
	_build_camera(_ship)
	_build_hud(_ship)
	_mission_def = load("res://data/missions/ghost_station.tres")
	if _mission_def == null:
		_mission_def = MissionDef.new()
	var dock := _build_station(_mission_def.station_distance)
	_build_mission(_ship, dock, _mission_def)
	_build_salvage(_ship)
	# Escalating threat: drones hunt harder the longer you linger / the more you grab.
	var heat := HeatDirector.new()
	heat.ship = _ship
	add_child(heat)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)
	EventBus.enemy_destroyed.connect(func() -> void: _drones_killed += 1)
	EventBus.mission_state_changed.connect(_on_mission_state_changed)

# ── co-op (M5 Phase 1b): each player flies their own ship in the shared sector;
# mission / drones come in later phases. ───────────────────────────────────────
func _setup_coop() -> void:
	_build_combat_net()   # host-authoritative bolts, replicated to all peers

	var ships_root := Node3D.new()
	ships_root.name = "Ships"
	add_child(ships_root)

	_spawner = MultiplayerSpawner.new()
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(ships_root)
	_spawner.spawn_function = _spawn_ship

	# Drones: built identically on every peer (so they replicate), host drives the AI.
	var enemies_root := Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	_enemy_spawner = MultiplayerSpawner.new()
	add_child(_enemy_spawner)
	_enemy_spawner.spawn_path = _enemy_spawner.get_path_to(enemies_root)
	_enemy_spawner.spawn_function = _spawn_drone

	# Spawn only once everyone has loaded (host-side), then announce we're in.
	Net.all_peers_in_raid.connect(_on_all_in_raid)
	Net.report_in_raid()

## Host only: now that every peer's spawner exists, spawn one ship per player.
func _on_all_in_raid(peer_ids: Array) -> void:
	if not multiplayer.is_server():
		return
	var sorted := peer_ids.duplicate()
	sorted.sort()   # deterministic slot assignment (host = peer 1 = slot 0)
	_coop_ships.clear()
	for slot in sorted.size():
		var s: Node = _spawner.spawn({"peer": sorted[slot], "slot": slot})
		if s != null:
			_coop_ships.append(s)

	# Host-only: escalating drone waves that hunt the players, spawned across the wire.
	var heat := HeatDirector.new()
	heat.players = _coop_ships
	heat.spawn_override = _coop_spawn_drone
	add_child(heat)

## Runs on EVERY peer (driven by the spawner) to build the same ship locally.
func _spawn_ship(data: Dictionary) -> Node:
	var peer_id := int(data["peer"])
	var slot := int(data.get("slot", 0))
	var ship := ShipController.new()
	ship.name = "Ship_%d" % peer_id
	# Baseline stats (no per-player upgrades yet) so the build is identical on all
	# peers; wiring profiles across the wire is a follow-up.
	var base_def := load("res://data/ships/wayfarer.tres")
	ship.ship_def = (base_def as ShipDef).duplicate()
	_assemble_ship(ship, PEER_HULL_COLORS[slot % PEER_HULL_COLORS.size()])
	ship.position = Vector3(slot * 18.0 - 9.0, 0.0, 0.0)
	var hsync := _add_ship_synchronizer(ship)
	ship.set_multiplayer_authority(peer_id)   # recursive: transform sync + weapon
	hsync.set_multiplayer_authority(1)         # but HEALTH is host-authoritative (damage adjudicated there)
	var mine := " (MINE)" if peer_id == multiplayer.get_unique_id() else ""
	print("raid: spawned %s authority=%d slot=%d%s" % [ship.name, peer_id, slot, mine])
	if peer_id == multiplayer.get_unique_id():
		_attach_local_view.call_deferred(ship)
	return ship

func _attach_local_view(ship: ShipController) -> void:
	_ship = ship
	_build_camera(ship)
	_build_hud(ship)

## Two synchronizers with SPLIT authority: transform replicates from the owning peer
## (they fly their ship), health replicates from the host (it adjudicates damage).
## Returns the health synchronizer so the caller can set its authority to the host.
func _add_ship_synchronizer(ship: ShipController) -> MultiplayerSynchronizer:
	var tcfg := SceneReplicationConfig.new()
	for path in [NodePath(".:position"), NodePath(".:rotation")]:
		tcfg.add_property(path)
		tcfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var tsync := MultiplayerSynchronizer.new()
	tsync.name = "XformSync"
	tsync.replication_config = tcfg
	ship.add_child(tsync)

	var hcfg := SceneReplicationConfig.new()
	for path in [NodePath(".:current_hull"), NodePath(".:current_shield")]:
		hcfg.add_property(path)
		hcfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var hsync := MultiplayerSynchronizer.new()
	hsync.name = "HealthSync"
	hsync.replication_config = hcfg
	ship.add_child(hsync)
	return hsync

# ── co-op drones (host-authoritative, replicated to all peers) ──────────────────
## Built on EVERY peer by the enemy spawner; the host owns AI + health.
func _spawn_drone(data: Dictionary) -> Node:
	var drone := EnemyDrone.new()
	drone.enemy_def = load(DRONE_DEF_PATH)
	var p: Array = data["pos"]
	drone.position = Vector3(p[0], p[1], p[2])
	_add_drone_synchronizer(drone)
	drone.set_multiplayer_authority(1)   # the host runs the AI; clients are puppets
	return drone

## Host: spawn a drone through the enemy spawner (replicated) and aim it at the
## nearest player. Passed to HeatDirector as its spawn_override.
func _coop_spawn_drone(_def: EnemyDef, pos: Vector3) -> void:
	var drone: Node = _enemy_spawner.spawn({"pos": [pos.x, pos.y, pos.z]})
	if drone != null:
		drone.target = _nearest_player(pos)

func _nearest_player(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for s in _coop_ships:
		if not is_instance_valid(s):
			continue
		var d: float = (s as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = s
	return best

func _add_drone_synchronizer(drone: Node) -> void:
	var cfg := SceneReplicationConfig.new()
	for path in [NodePath(".:position"), NodePath(".:rotation")]:
		cfg.add_property(path)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = cfg
	drone.add_child(sync)

func _seed_rng() -> void:
	if Net.active:
		_rng.seed = Net.world_seed   # identical sector on every peer
	else:
		_rng.randomize()

func _unhandled_input(event: InputEvent) -> void:
	# The options overlay (SettingsMenu) handles "toggle_settings" itself, since it
	# keeps processing while the game is paused — main can't, so it stays out of it.
	if event.is_action_pressed("toggle_fullscreen"):
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		_apply_fullscreen(not is_fs)
		_set_capture(true)
	elif event.is_action_pressed("quit_game"):
		get_tree().quit()

func _process(_delta: float) -> void:
	# macOS silently drops mouse capture when the window crosses displays or
	# Spaces (the cursor reappears and steering dies). Re-assert capture every
	# frame while focused and wanted, so it's grabbed back immediately.
	if _want_capture and not Settings.input_locked and get_window().has_focus() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	# Immediate re-grab on focus/enter events (Cmd-Tab, mouse re-entering), but not
	# while the options menu is open (it wants a free cursor).
	if not _want_capture or Settings.input_locked:
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
	# Shared with the flyable lobby; registered in code (project.godot stays clean).
	InputSetup.configure()

# ── world ─────────────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.97, 0.92)   # faint warm key so the cool ambient has contrast
	add_child(sun)

	var env := Environment.new()
	# Real Milky Way panorama (8K equirectangular) rendered at infinity. It reads as
	# deep space with genuine depth, without the parallaxing near-field star dots
	# that felt claustrophobic.
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/textures/sky/nebula_raid_multi.hdr")   # dramatic multi-colour nebula
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

	# Soft, wide bloom so engines/bolts/explosions read as glowing light sources.
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.85
	# Spread bloom across several blur levels for a soft falloff rather than a halo.
	env.set_glow_level(1, 0.8)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.4)

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

## Phoenix as a far backdrop for the first mission area. Loaded by path so the new
## PlanetBackdrop class works before the editor refreshes its class cache; it picks
## 1K or 4K itself from how big it appears here.
func _build_planet() -> void:
	var planet: Node3D = (load("res://scripts/core/planet_backdrop.gd") as GDScript).new()
	planet.radius = 700.0
	planet.viewer = Vector3.ZERO            # the player spawns near origin
	planet.position = Vector3(-1000, 520, -2550)   # off to one side, beyond the station
	add_child(planet)

func _build_ship() -> ShipController:
	var ship := ShipController.new()
	ship.name = "Wayfarer"
	# Outfit the base hull with the player's owned upgrades (M4); base .tres is
	# left untouched — UpgradeSystem returns a modified copy.
	var base_def := load("res://data/ships/wayfarer.tres")
	if base_def is ShipDef:
		ship.ship_def = UpgradeSystem.outfit(base_def, PlayerProfile.owned_upgrades)
	_assemble_ship(ship, PEER_HULL_COLORS[0])
	add_child(ship)
	# Carry persisted damage into the run (repairing at the station restores it),
	# but floor it so an unrepaired ship is never launched dead/unplayable.
	ship.current_hull = ship.ship_def.hull_max * clampf(PlayerProfile.ship_hull_pct, 0.3, 1.0)
	return ship

## Builds a ship's visuals, collision, weapon, and cargo onto `ship` (whose
## ship_def must already be set). Shared by solo and co-op spawning.
func _assemble_ship(ship: ShipController, hull_color: Color) -> void:
	# Visual hull: the imported GLB model. If it hasn't imported yet the ship still
	# flies — collision and weapon are independent of the visual.
	var model := _spawn_model(SHIP_MODEL_PATH, SHIP_MODEL_SCALE, SHIP_MODEL_EULER, SHIP_MODEL_CENTER)
	if model != null:
		ship.add_child(model)

	# Body: player_ship layer, collides with the environment (asteroids); bolts
	# detect it via this layer.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Hitbox tracks the scaled model bounds, rotated to match the model's facing,
	# tucked in slightly for forgiving flight.
	var ext := (Basis.from_euler(SHIP_MODEL_EULER * (PI / 180.0)) * SHIP_MODEL_BOUNDS).abs()
	shape.size = ext * SHIP_MODEL_SCALE * 0.9
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

	# Cargo hold (carries the Data Core / salvage this run); slots bound greed.
	var cargo := CargoSystem.new()
	cargo.max_slots = ship.ship_def.cargo_slots
	ship.add_child(cargo)
	ship.cargo = cargo

	# Engine glow + thruster plume + speed dust (presentation only; reads ship
	# motion, so it works on remote puppet ships too). Engines tint per player slot.
	var fx := ShipFX.new()
	fx.engine_color = hull_color.lerp(Color(1.0, 0.5, 0.2), 0.6)   # warm afterburner, slight slot tint
	ship.add_child(fx)

## Instantiates an imported GLB under a pivot that scales + rotates it, with a
## recenter child that cancels the model's origin offset (so its bounding-box
## centre sits at the returned node's origin). Returns null if the model hasn't
## been imported yet — callers keep working with no visual.
func _spawn_model(path: String, model_scale: float, euler: Vector3, center: Vector3) -> Node3D:
	return ModelUtil.spawn(path, model_scale, euler, center)

func _build_camera(ship: ShipController) -> void:
	var cam := ChaseCamera.new()
	cam.target_path = ship.get_path()
	add_child(cam)
	cam.current = true
	_camera = cam

func _build_hud(ship: ShipController) -> void:
	var hud := ShipHUD.new()
	hud.ship = ship
	hud.camera = _camera   # for the lead pip + velocity vector markers
	add_child(hud)
	# Options overlay (Esc / PS5 Options): toggle + tune the HUD markers in-flight.
	# Loaded by path so it works even before the editor refreshes the global-class
	# cache for the new SettingsMenu class (avoids the stale-cache trap).
	var menu_script: GDScript = load("res://scripts/ui/settings_menu.gd")
	add_child(menu_script.new())

func _build_asteroids() -> void:
	var meshes := _load_asteroid_meshes()   # the 3 rock meshes from the GLB
	for i in ASTEROID_COUNT:
		# Solid rock: a StaticBody3D on the environment layer so the ship stops on it.
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_ENVIRONMENT
		# Place in a shell around origin so the spawn point stays clear.
		body.position = _random_unit() * _rng.randf_range(40.0, 260.0)
		body.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)

		var target_r := _rng.randf_range(2.0, 7.0)   # gameplay radius, independent of model size
		if meshes.is_empty():
			_add_placeholder_rock(body, target_r)     # model not imported yet → procedural sphere
		else:
			# Pick a rock mesh and uniform-scale it to the target radius, so the three
			# differently-sized source rocks read as a consistent field.
			var mesh: Mesh = meshes[_rng.randi() % meshes.size()]
			var aabb := mesh.get_aabb()
			var s := target_r / maxf(0.01, aabb.size.length() * 0.5)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.scale = Vector3.ONE * s
			mi.position = -aabb.get_center() * s       # centre the rock on the body origin
			body.add_child(mi)
			var col := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = target_r * 0.6              # snug sphere inside the lumpy rock
			col.shape = shape
			body.add_child(col)
		add_child(body)

## Pulls the distinct rock meshes out of the asteroid GLB once, to instance across
## the field. Returns [] if the model hasn't been imported (caller falls back).
func _load_asteroid_meshes() -> Array:
	var out: Array = []
	var scene := load(ASTEROID_MODEL_PATH)
	if not (scene is PackedScene):
		push_warning("asteroid model not imported yet: %s" % ASTEROID_MODEL_PATH)
		return out
	var inst := (scene as PackedScene).instantiate()
	_collect_meshes(inst, out)
	inst.queue_free()   # we keep the Mesh resources; the node tree is disposable
	return out

func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append((node as MeshInstance3D).mesh)
	for c in node.get_children():
		_collect_meshes(c, out)

## Fallback rock when the asteroid model isn't available, so the field is never empty.
func _add_placeholder_rock(body: StaticBody3D, r: float) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 4
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	var g := _rng.randf_range(0.25, 0.45)
	mat.albedo_color = Color(g, g * 0.95, g * 0.9)
	mat.roughness = 1.0
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = r * 0.9
	col.shape = shape
	body.add_child(col)

## Builds the derelict station (placeholder primitives) and returns its docking
## zone so the MissionManager can wire the dock objective to it.
func _build_station(distance: float) -> ShipZone:
	var station := Node3D.new()
	station.position = Vector3(0, 0, -distance)   # straight ahead of the spawn point
	add_child(station)

	# Visual hull: the imported GLB station (recentered + scaled). The dock zone
	# below still works even if the model hasn't imported yet.
	var model := _spawn_model(STATION_MODEL_PATH, STATION_MODEL_SCALE, STATION_MODEL_EULER, STATION_MODEL_CENTER)
	var station_radius := 0.0
	if model != null:
		station.add_child(model)
		# Make the derelict solid: trimesh colliders that follow the visible hull, so
		# you crash into it / fly through its gaps instead of phasing through.
		_add_solid_collision(model)
		station_radius = _model_bounds_radius(station, model)

	# The Data Core itself — a glowing server rack at the station's heart, so the
	# objective you hack out is something you can see and fly toward.
	var core := _spawn_model(DATACORE_MODEL_PATH, DATACORE_MODEL_SCALE, Vector3.ZERO, DATACORE_MODEL_CENTER)
	if core != null:
		station.add_child(core)
	var core_light := OmniLight3D.new()
	core_light.light_color = Color(0.4, 0.9, 1.0)
	core_light.light_energy = 4.0
	core_light.omni_range = 70.0
	station.add_child(core_light)

	# Red running light so the huge derelict is findable and lit in the dark sector.
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.3, 0.25)
	beacon.light_energy = 5.0
	beacon.omni_range = 300.0
	station.add_child(beacon)

	# Dock trigger. Now that the hull is solid, make sure the trigger reaches the
	# station's exterior so you can still dock on approach (rather than needing to
	# fly inside a solid shell); never smaller than the original reach.
	var dock := ShipZone.new()
	dock.radius = maxf(130.0, station_radius + 20.0)
	dock.marker_radius = 22.0
	dock.marker_color = Color(0.3, 0.7, 1.0)
	station.add_child(dock)
	return dock

## Gives every mesh in a spawned model a trimesh StaticBody on the environment
## layer, turning the visible geometry solid. Trimesh follows the real hull, so
## openings stay flyable; ship/asteroid masks already collide with this layer.
func _add_solid_collision(model: Node3D) -> void:
	var meshes: Array = []
	_collect_mesh_instances(model, meshes)
	for mi in meshes:
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_ENVIRONMENT
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		col.shape = inst.mesh.create_trimesh_shape()
		body.add_child(col)
		inst.add_child(body)

func _collect_mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_mesh_instances(c, out)

## World-space bounding radius of a spawned model around `center_node`'s origin —
## used to size the dock trigger so it clears the now-solid hull.
func _model_bounds_radius(center_node: Node3D, model: Node3D) -> float:
	var meshes: Array = []
	_collect_mesh_instances(model, meshes)
	var center := center_node.global_position
	var r := 0.0
	for mi in meshes:
		var inst := mi as MeshInstance3D
		var ab := inst.get_aabb()
		var gt := inst.global_transform
		for i in 8:
			var corner := ab.position + Vector3(
				ab.size.x if (i & 1) != 0 else 0.0,
				ab.size.y if (i & 2) != 0 else 0.0,
				ab.size.z if (i & 4) != 0 else 0.0)
			r = maxf(r, (gt * corner).distance_to(center))
	return r

func _build_mission(ship: ShipController, dock: ShipZone, mdef: MissionDef) -> void:
	var mm := MissionManager.new()
	mm.mission_def = mdef
	mm.setup(ship, ship.cargo, dock)
	add_child(mm)

## Scatters salvage crates through the sector — the greed half of the loop. Three
## value tiers (rarer = worth more), each a colour-coded beacon you fly into.
func _build_salvage(_ship: ShipController) -> void:
	var tiers := [
		{"id": "scrap", "value": 40, "color": Color(0.5, 1.0, 0.7)},
		{"id": "alloy", "value": 95, "color": Color(0.4, 0.7, 1.0)},
		{"id": "relic", "value": 190, "color": Color(1.0, 0.8, 0.3)},
	]
	for i in SALVAGE_COUNT:
		var roll := _rng.randf()
		var tier: Dictionary = tiers[0] if roll < 0.55 else (tiers[1] if roll < 0.85 else tiers[2])
		var pickup := SalvagePickup.new()
		pickup.value = int(tier["value"])
		pickup.salvage_id = String(tier["id"])
		pickup.tier_color = tier["color"]
		var model := _spawn_model(SALVAGE_MODEL_PATH, SALVAGE_MODEL_SCALE,
			Vector3(0.0, _rng.randf() * 360.0, 0.0), SALVAGE_MODEL_CENTER)
		if model != null:
			pickup.add_child(model)
		pickup.position = _random_unit() * _rng.randf_range(60.0, 280.0)
		add_child(pickup)

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
	var salvage_value: int = _ship.cargo.salvage_value if _ship.cargo != null else 0
	var reward := RewardCalculator.compute(success, _drones_killed, has_core, _mission_def.reward_credits, salvage_value)

	PlayerProfile.credits += reward
	if success:
		PlayerProfile.mission_completions += 1
		if _ship.cargo != null:
			PlayerProfile.total_cargo_extracted += _ship.cargo.items.size()
	PlayerProfile.ship_hull_pct = clampf(_ship.current_hull / _ship.ship_def.hull_max, 0.0, 1.0)
	PlayerProfile.save_profile()
	var salvage_count: int = 0
	if _ship.cargo != null:
		salvage_count = _ship.cargo.slots_used() - (1 if has_core else 0)
	PlayerProfile.last_run = {
		"success": success,
		"credits_earned": reward,
		"drones_killed": _drones_killed,
		"data_core": has_core,
		"salvage_value": salvage_value if success else 0,
		"salvage_count": salvage_count if success else 0,
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
