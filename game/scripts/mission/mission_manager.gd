class_name MissionManager
extends Node
## Simulation: the Ghost Station mission FSM (GDD §5.1, §26.3–26.5). Owns mission
## state, the hack and meltdown timers, enemy-wave spawning, and win/lose. It
## touches the world only through node refs set by main() and through EventBus
## signals — no camera/HUD/input coupling, so it is host-authoritative-ready.

enum State { APPROACH, HACK, EXTRACT, SUCCESS, FAILED }

const DATA_CORE := "data_core"
const DRONE_DEF_PATH := "res://data/enemies/light_drone.tres"

@export var mission_def: MissionDef

var ship: ShipController
var cargo: CargoSystem
var docking_zone: ShipZone

var _state: int = State.APPROACH
var _can_dock: bool = false
var _hack_left: float = 0.0
var _extract_left: float = 0.0
var _wave_timer: float = 0.0
var _enemy_def: EnemyDef

func setup(p_ship: ShipController, p_cargo: CargoSystem, p_docking_zone: ShipZone) -> void:
	ship = p_ship
	cargo = p_cargo
	docking_zone = p_docking_zone

func _ready() -> void:
	if mission_def == null:
		mission_def = MissionDef.new()
	var def := load(DRONE_DEF_PATH)
	if def is EnemyDef:
		_enemy_def = def
	docking_zone.ship_entered.connect(_on_dock_entered)
	docking_zone.ship_exited.connect(_on_dock_exited)
	EventBus.ship_destroyed.connect(func() -> void: _fail("Ship destroyed"))
	_set_state(State.APPROACH)
	EventBus.objective_updated.emit("Fly to the derelict station and dock")

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.APPROACH and _can_dock and event.is_action_pressed("dock"):
		_enter_hack()

func _process(delta: float) -> void:
	match _state:
		State.HACK:
			_hack_left = maxf(0.0, _hack_left - delta)
			EventBus.objective_updated.emit("HACKING DATA CORE — hold the station  (%ds)" % ceili(_hack_left))
			_tick_waves(delta, mission_def.hack_wave_size)
			if _hack_left <= 0.0:
				_enter_extract()
		State.EXTRACT:
			_extract_left = maxf(0.0, _extract_left - delta)
			EventBus.extraction_timer_changed.emit(_extract_left)
			_tick_waves(delta, mission_def.extract_wave_size)
			if _extract_left <= 0.0:
				_fail("Reactor meltdown — you didn't make it out")

# ── state transitions ─────────────────────────────────────────────────────────
func _on_dock_entered() -> void:
	if _state != State.APPROACH:
		return
	_can_dock = true
	EventBus.docking_available.emit(true)
	EventBus.objective_updated.emit("PRESS F TO DOCK")

func _on_dock_exited() -> void:
	_can_dock = false
	EventBus.docking_available.emit(false)
	if _state == State.APPROACH:
		EventBus.objective_updated.emit("Fly to the derelict station and dock")

func _enter_hack() -> void:
	_can_dock = false
	EventBus.docking_available.emit(false)
	_hack_left = mission_def.hack_duration
	_wave_timer = mission_def.wave_interval
	_set_state(State.HACK)
	_spawn_wave(mission_def.hack_wave_size)

func _enter_extract() -> void:
	cargo.add_item(DATA_CORE)
	_extract_left = mission_def.extract_duration
	_spawn_extraction_zone()
	_set_state(State.EXTRACT)
	EventBus.objective_updated.emit("DATA CORE SECURED — reach the extraction point!")

func _succeed() -> void:
	if _state != State.EXTRACT:
		return
	_set_state(State.SUCCESS)
	_clear_enemies()
	EventBus.objective_updated.emit("EXTRACTED — Data Core recovered  (+%d credits)" % mission_def.reward_credits)

func _fail(reason: String) -> void:
	if _state == State.SUCCESS or _state == State.FAILED:
		return
	_set_state(State.FAILED)
	EventBus.objective_updated.emit("MISSION FAILED — %s" % reason)

func _set_state(s: int) -> void:
	_state = s
	EventBus.mission_state_changed.emit(_state_name(s))

func _state_name(s: int) -> String:
	match s:
		State.APPROACH: return "approach"
		State.HACK: return "hack"
		State.EXTRACT: return "extract"
		State.SUCCESS: return "success"
		State.FAILED: return "failed"
	return "unknown"

# ── enemy waves ─────────────────────────────────────────────────────────────
func _tick_waves(delta: float, size: int) -> void:
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = mission_def.wave_interval
		_spawn_wave(size)

func _spawn_wave(count: int) -> void:
	var scene := _spawn_root()
	for i in count:
		var drone := EnemyDrone.new()
		if _enemy_def != null:
			drone.enemy_def = _enemy_def
		drone.target = ship
		drone.position = ship.global_position + _rand_dir() * randf_range(70.0, 110.0)
		scene.add_child(drone)

func _spawn_extraction_zone() -> void:
	var zone := ShipZone.new()
	zone.radius = 22.0
	zone.marker_color = Color(0.4, 1.0, 0.5)
	var dir := _rand_dir()
	zone.position = ship.global_position + dir * mission_def.extraction_distance
	zone.ship_entered.connect(_succeed)
	_spawn_root().add_child(zone)

## Where spawned drones / zones are parented. In-game this is the raid scene root
## (the MissionManager's parent); in tests it's a node the test owns. Decoupling
## from get_tree().current_scene is what makes the FSM unit-testable.
func _spawn_root() -> Node:
	return get_parent()

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

func _rand_dir() -> Vector3:
	# Bias toward the horizontal plane so objectives stay easy to find and reach.
	var v := Vector3(randf() - 0.5, (randf() - 0.5) * 0.4, randf() - 0.5)
	if v.length() < 0.01:
		v = Vector3.FORWARD
	return v.normalized()
