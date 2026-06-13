extends Node
## Global signal bus (autoload "EventBus"). Decouples systems so UI, audio, and
## the ship-AI voice can react to gameplay without direct references.
## See ../../docs/ARCHITECTURE.md §3.

# Ship / combat
signal ship_hull_changed(current: float, maximum: float)
signal ship_shield_changed(current: float, maximum: float)
signal ship_system_damaged(system: String)
signal ship_destroyed

# Combat feedback (M2)
signal shot_fired(team: String)            # "player" | "enemy" | "missile"
signal hit_landed(team: String, at: Vector3)
signal enemy_died(at: Vector3)
signal player_hit
signal pickup_collected(kind: String)
signal wave_started(number: int, is_boss: bool)

# Mission (used from Milestone 3 onward)
signal mission_state_changed(state: String)
signal objective_updated(text: String)
signal extraction_timer_changed(seconds_left: float)
