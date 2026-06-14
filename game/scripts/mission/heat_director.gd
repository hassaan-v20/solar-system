class_name HeatDirector
extends Node
## Simulation: the escalating-threat "heat" system — the risk half of the salvage
## loop. Heat rises with time lingering in the sector AND with every salvage grab,
## and higher heat means faster, bigger drone waves. So "grab one more crate?" is a
## visible gamble: each crate you take cranks the threat that's hunting you.
##
## Host-authoritative-ready: it only reads the ship's transform and reacts to
## EventBus signals; it never touches input/camera/HUD. Tuning constants are local.

const DRONE_DEF_PATH := "res://data/enemies/light_drone.tres"
const TIME_TO_MAX := 150.0       # seconds of lingering to reach max heat on time alone
const HEAT_PER_SALVAGE := 0.12   # each crate grabbed cranks the threat
const SPAWN_SLOW := 13.0         # seconds between waves at zero heat
const SPAWN_FAST := 3.5          # seconds between waves at max heat
const MAX_ALIVE := 8             # cap concurrent drones so it never runs away
const SPAWN_MIN := 80.0
const SPAWN_MAX := 130.0

var ship: ShipController
var active: bool = true

var _heat: float = 0.0
var _cooldown: float = 0.0
var _emit_t: float = 0.0
var _enemy_def: EnemyDef
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var def := load(DRONE_DEF_PATH)
	if def is EnemyDef:
		_enemy_def = def
	_cooldown = SPAWN_SLOW
	EventBus.salvage_collected.connect(_on_salvage)
	EventBus.mission_state_changed.connect(_on_mission_state)

func _on_salvage(_value: int) -> void:
	_heat = clampf(_heat + HEAT_PER_SALVAGE, 0.0, 1.0)
	EventBus.heat_changed.emit(_heat)

func _on_mission_state(state: String) -> void:
	if state == "success" or state == "failed":
		active = false   # the run is over; stop hunting

func _process(delta: float) -> void:
	if not active or ship == null or not is_instance_valid(ship):
		return
	_heat = clampf(_heat + delta / TIME_TO_MAX, 0.0, 1.0)
	# Throttle the HUD signal; the value barely moves frame to frame.
	_emit_t += delta
	if _emit_t >= 0.2:
		_emit_t = 0.0
		EventBus.heat_changed.emit(_heat)
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = lerpf(SPAWN_SLOW, SPAWN_FAST, _heat)
		_spawn_wave()

func _spawn_wave() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_ALIVE:
		return
	var count := 1 + int(round(_heat * 2.0))   # 1..3 drones, scaling with heat
	for i in count:
		var drone := EnemyDrone.new()
		if _enemy_def != null:
			drone.enemy_def = _enemy_def
		drone.target = ship
		drone.position = ship.global_position + _rand_dir() * _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		get_parent().add_child(drone)

func _rand_dir() -> Vector3:
	# Bias toward the horizontal plane so threats come from around, not above/below.
	var v := Vector3(_rng.randf() - 0.5, (_rng.randf() - 0.5) * 0.4, _rng.randf() - 0.5)
	if v.length() < 0.01:
		v = Vector3.FORWARD
	return v.normalized()
