class_name MissionManager
extends Node
## Milestone 3 — a single raid loop as a state machine (GDD §"raid objectives").
## TRAVEL to a derelict station → HACK its data core → EXTRACT at the jump point
## before the timer runs out. Drives the HUD through EventBus mission signals.

enum State { TRAVEL, HACK, EXTRACT, COMPLETE, FAILED }

var world: Node3D
var ship: Node3D

const STATION_POS := Vector3(300.0, 30.0, 240.0)
const EXTRACT_POS := Vector3(-340.0, -20.0, -300.0)
const HACK_TIME := 7.0          # seconds inside the core to finish the hack
const EXTRACT_TIME := 80.0

var _state: int = State.TRAVEL
var _hack: float = 0.0
var _timer: float = 0.0
var _in_hack: bool = false
var _in_extract: bool = false

func begin() -> void:
	_build_station()
	EventBus.ship_destroyed.connect(_on_ship_dead)
	_set_state(State.TRAVEL)

func _process(delta: float) -> void:
	match _state:
		State.HACK:
			if _in_hack:
				_hack += delta
				EventBus.objective_updated.emit("HACKING DATA CORE … %d%%" % int(100.0 * _hack / HACK_TIME))
				if _hack >= HACK_TIME:
					_start_extract()
			else:
				EventBus.objective_updated.emit("Return to the station core to resume the hack")
		State.EXTRACT:
			_timer -= delta
			EventBus.extraction_timer_changed.emit(maxf(0.0, _timer))
			if _in_extract:
				_finish(State.COMPLETE, "EXTRACTION SUCCESSFUL")
			elif _timer <= 0.0:
				_finish(State.FAILED, "EXTRACTION WINDOW CLOSED")

func _set_state(s: int) -> void:
	_state = s
	var names := ["travel", "hack", "extract", "complete", "failed"]
	EventBus.mission_state_changed.emit(names[s])
	if s == State.TRAVEL:
		EventBus.objective_updated.emit("Fly to the derelict station")

func _start_extract() -> void:
	_build_extract_gate()
	_timer = EXTRACT_TIME
	_set_state(State.EXTRACT)
	EventBus.objective_updated.emit("DATA SECURED — extract at the jump point!")

func _finish(s: int, _msg: String) -> void:
	_set_state(s)
	set_process(false)

func _on_ship_dead() -> void:
	if _state in [State.TRAVEL, State.HACK, State.EXTRACT]:
		_finish(State.FAILED, "SHIP LOST")

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
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.3, 0.9, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.9, 1.0)
	glow.emission_energy_multiplier = 3.0

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
	# Glowing data core at the centre.
	var core := SphereMesh.new()
	core.radius = 3.0
	core.height = 6.0
	_smesh(root, core, Vector3.ZERO, Vector3.ZERO, glow)

	var zone := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 26.0
	cs.shape = sph
	zone.add_child(cs)
	root.add_child(zone)
	zone.body_entered.connect(_on_hack_enter)
	zone.body_exited.connect(_on_hack_exit)

func _build_extract_gate() -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = EXTRACT_POS
	root.add_to_group("objective")
	root.set_meta("label", "JUMP POINT")

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.4, 1.0, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(0.4, 1.0, 0.6)
	glow.emission_energy_multiplier = 4.0
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

func _on_hack_enter(b: Node) -> void:
	if not b.is_in_group("player"):
		return
	_in_hack = true
	if _state == State.TRAVEL:
		_set_state(State.HACK)

func _on_hack_exit(b: Node) -> void:
	if b.is_in_group("player"):
		_in_hack = false

func _smesh(parent: Node3D, mesh: Mesh, pos: Vector3, rot_deg: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
