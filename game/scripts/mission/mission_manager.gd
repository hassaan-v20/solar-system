class_name MissionManager
extends Node
## Milestone 3 — data-driven raid loop. Reads a MissionDef and runs one of four
## contract types to an extraction. Drives the HUD via EventBus mission signals
## and asks main for enemy reinforcements via EventBus.mission_spawn.

enum State { ACTIVE, EXTRACT, COMPLETE, FAILED }

@export var mission_def: MissionDef
var world: Node3D
var ship: Node3D

const STATION_POS := Vector3(300.0, 30.0, 240.0)
const EXTRACT_POS := Vector3(-340.0, -20.0, -300.0)

var _state: int = State.ACTIVE
var _hold: float = 0.0
var _timer: float = 0.0
var _reinf_t: float = 0.0
var _in_zone: bool = false
var _in_extract: bool = false
var _collected: int = 0
var _kills: int = 0

func _ready() -> void:
	EventBus.ship_destroyed.connect(_on_ship_dead)
	EventBus.enemy_died.connect(_on_enemy_died)

func begin() -> void:
	if mission_def == null:
		mission_def = MissionDef.new()
	_state = State.ACTIVE
	_reinf_t = mission_def.reinforce_gap
	EventBus.mission_state_changed.emit("active")
	EventBus.objective_updated.emit(mission_def.display_name)
	match mission_def.mission_type:
		"hack", "defend":
			_build_station()
		"salvage":
			_build_caches()
	EventBus.mission_spawn.emit(mission_def.start_enemies, _focus(), false)

func _process(delta: float) -> void:
	if _state == State.COMPLETE or _state == State.FAILED:
		return
	_reinf_t -= delta
	if _reinf_t <= 0.0:
		_reinf_t = mission_def.reinforce_gap
		EventBus.mission_spawn.emit(mission_def.reinforce, _focus(), false)

	if _state == State.ACTIVE:
		_tick_active(delta)
	elif _state == State.EXTRACT:
		_timer -= delta
		EventBus.extraction_timer_changed.emit(maxf(0.0, _timer))
		if _in_extract:
			_finish(State.COMPLETE)
		elif _timer <= 0.0:
			_finish(State.FAILED)

func _tick_active(delta: float) -> void:
	match mission_def.mission_type:
		"hack":
			if _in_zone:
				_hold += delta
				EventBus.objective_updated.emit("HACKING DATA CORE … %d%%" % _pct())
				if _hold >= mission_def.hold_time:
					_to_extract()
			else:
				EventBus.objective_updated.emit("Reach the station core to hack it")
		"defend":
			if _in_zone:
				_hold += delta
				EventBus.objective_updated.emit("HOLD THE STATION … %d s" % int(ceil(mission_def.hold_time - _hold)))
				if _hold >= mission_def.hold_time:
					_to_extract()
			else:
				EventBus.objective_updated.emit("Get back to the station and hold it!")
		"salvage":
			EventBus.objective_updated.emit("RECOVER SALVAGE  %d / %d" % [_collected, mission_def.target_count])
			if _collected >= mission_def.target_count:
				_to_extract()
		"bounty":
			EventBus.objective_updated.emit("DESTROY RAIDERS  %d / %d" % [_kills, mission_def.target_count])
			if _kills >= mission_def.target_count:
				_to_extract()

func _to_extract() -> void:
	_build_extract_gate()
	_timer = mission_def.extract_time
	_state = State.EXTRACT
	EventBus.mission_state_changed.emit("extract")
	EventBus.objective_updated.emit("OBJECTIVE COMPLETE — extract at the jump point!")
	EventBus.mission_spawn.emit(mission_def.extract_reinforce, ship.global_position if ship else Vector3.ZERO, false)

func _finish(s: int) -> void:
	_state = s
	EventBus.mission_state_changed.emit("complete" if s == State.COMPLETE else "failed")
	set_process(false)

func _on_ship_dead() -> void:
	if _state == State.ACTIVE or _state == State.EXTRACT:
		_finish(State.FAILED)

func _on_enemy_died(_at: Vector3) -> void:
	if _state == State.ACTIVE and mission_def.mission_type == "bounty":
		_kills += 1

func _pct() -> int:
	return int(100.0 * _hold / maxf(0.1, mission_def.hold_time))

func _focus() -> Vector3:
	if mission_def.mission_type in ["hack", "defend"]:
		return STATION_POS
	return ship.global_position if ship else Vector3.ZERO

# ── world structures ──────────────────────────────────────────────────────────
func _build_station() -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = STATION_POS
	root.add_to_group("objective")
	root.set_meta("label", "STATION")

	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.45, 0.48, 0.55)
	hull.metallic = 0.7
	hull.roughness = 0.4
	var glow := _glow_mat(Color(0.3, 0.9, 1.0))

	var hub := CylinderMesh.new()
	hub.top_radius = 6.0
	hub.bottom_radius = 6.0
	hub.height = 10.0
	_smesh(root, hub, Vector3.ZERO, Vector3(90, 0, 0), hull)
	var ring := TorusMesh.new()
	ring.inner_radius = 14.0
	ring.outer_radius = 18.0
	_smesh(root, ring, Vector3.ZERO, Vector3.ZERO, hull)
	for a in 4:
		var arm := BoxMesh.new()
		arm.size = Vector3(2.0, 2.0, 12.0)
		_smesh(root, arm, Vector3.ZERO, Vector3(0, a * 45.0, 0), hull)
	var core := SphereMesh.new()
	core.radius = 3.0
	core.height = 6.0
	_smesh(root, core, Vector3.ZERO, Vector3.ZERO, glow)

	var zone := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 30.0
	cs.shape = sph
	zone.add_child(cs)
	root.add_child(zone)
	zone.body_entered.connect(func(b): if b.is_in_group("player"): _in_zone = true)
	zone.body_exited.connect(func(b): if b.is_in_group("player"): _in_zone = false)

func _build_caches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in mission_def.target_count:
		var root := Node3D.new()
		world.add_child(root)
		var dir := Vector3(rng.randfn(), rng.randfn() * 0.4, rng.randfn()).normalized()
		root.global_position = dir * rng.randf_range(150.0, 320.0)
		root.add_to_group("objective")
		root.set_meta("label", "SALVAGE")
		var glow := _glow_mat(Color(1.0, 0.85, 0.3))
		var m := BoxMesh.new()
		m.size = Vector3(3.0, 3.0, 3.0)
		_smesh(root, m, Vector3.ZERO, Vector3(rng.randf() * 40, rng.randf() * 40, 0), glow)
		var zone := Area3D.new()
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 6.0
		cs.shape = sph
		zone.add_child(cs)
		root.add_child(zone)
		zone.body_entered.connect(_on_cache_taken.bind(root))

func _on_cache_taken(b: Node, cache: Node3D) -> void:
	if b.is_in_group("player") and is_instance_valid(cache):
		_collected += 1
		EventBus.pickup_collected.emit("salvage")
		cache.queue_free()

func _build_extract_gate() -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = EXTRACT_POS
	root.add_to_group("objective")
	root.set_meta("label", "JUMP POINT")
	var glow := _glow_mat(Color(0.4, 1.0, 0.6))
	var ring := TorusMesh.new()
	ring.inner_radius = 12.0
	ring.outer_radius = 15.0
	_smesh(root, ring, Vector3.ZERO, Vector3(90, 0, 0), glow)
	var zone := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 16.0
	cs.shape = sph
	zone.add_child(cs)
	root.add_child(zone)
	zone.body_entered.connect(func(b): if b.is_in_group("player"): _in_extract = true)

func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.5
	return m

func _smesh(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
