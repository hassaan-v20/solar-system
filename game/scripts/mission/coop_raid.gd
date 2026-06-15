class_name CoopRaid
extends Node
## Host-authoritative co-op mission (Simulation). Fly to the derelict station and
## dock (F) to begin; the station then "wakes up" and you defend it against
## escalating drone waves for DEFEND_DURATION. Survive → raid complete; every ship
## down → raid failed.
##
## Only the host runs the logic (dock detection, timer, win/lose). State reaches
## clients by re-emitting EventBus signals through RPCs, so each peer's HUD reacts
## without the clients running any mission code (mirrors MissionManager's decoupling).

signal started   # host-side: the raid has begun — main spins up the HeatDirector waves

const DEFEND_DURATION := 90.0
const APPROACH_OBJECTIVE := "Fly into the derelict station to begin the raid"

enum State { APPROACH, DEFEND, SUCCESS, FAILED }

var dock_zone: ShipZone   # set by main before add_child

var _state: int = State.APPROACH
var _left: float = DEFEND_DURATION

func _ready() -> void:
	EventBus.objective_updated.emit(APPROACH_OBJECTIVE)   # local default on every peer
	# Only the host watches the dock trigger and drives the mission.
	if _is_host() and dock_zone != null:
		dock_zone.ship_entered.connect(_on_ship_entered)

func _on_ship_entered() -> void:
	if _state != State.APPROACH:
		return
	_state = State.DEFEND
	_left = DEFEND_DURATION
	started.emit()
	_set_objective("RAID LIVE — defend the station! Hold for %s" % _clock(_left))

func _process(delta: float) -> void:
	if _state != State.DEFEND or not _is_host():
		return
	var prev := ceili(_left)
	_left = maxf(0.0, _left - delta)
	if ceili(_left) != prev:
		_set_objective("DEFEND THE STATION — hold for %s" % _clock(_left))
	if _left <= 0.0:
		_finish(State.SUCCESS, "success", "STATION HELD — raid complete!")
	elif _all_players_dead():
		_finish(State.FAILED, "failed", "ALL SHIPS DOWN — raid failed")

func _finish(s: int, state_name: String, text: String) -> void:
	_state = s
	_set_state(state_name)
	_set_objective(text)

func _all_players_dead() -> bool:
	var ships := get_tree().get_nodes_in_group("players")
	if ships.is_empty():
		return false
	for p in ships:
		if is_instance_valid(p) and (p as ShipController).alive:
			return false
	return true

func _clock(t: float) -> String:
	var s := ceili(t)
	return "%d:%02d" % [s / 60, s % 60]

## Host in co-op, or solo (no net). Non-host clients never drive state.
func _is_host() -> bool:
	return not Net.active or multiplayer.is_server()

# ── broadcast: solo emits locally; the co-op host fans out to every peer ─────────
func _set_objective(text: String) -> void:
	if Net.active:
		_rpc_objective.rpc(text)
	else:
		EventBus.objective_updated.emit(text)

func _set_state(state_name: String) -> void:
	if Net.active:
		_rpc_state.rpc(state_name)
	else:
		EventBus.mission_state_changed.emit(state_name)

@rpc("authority", "call_local", "reliable")
func _rpc_objective(text: String) -> void:
	EventBus.objective_updated.emit(text)

@rpc("authority", "call_local", "reliable")
func _rpc_state(state_name: String) -> void:
	EventBus.mission_state_changed.emit(state_name)
