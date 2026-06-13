extends Node
## Global signal bus (autoload "EventBus"). Decouples systems so UI, audio, and
## the ship-AI voice can react to gameplay without direct references.
## See ../../docs/ARCHITECTURE.md §3.

# Ship / combat
signal ship_hull_changed(current: float, maximum: float)
signal ship_shield_changed(current: float, maximum: float)
signal ship_system_damaged(system: String)
signal ship_hit(amount: float)
signal ship_destroyed
signal enemy_destroyed

# Mission (used from Milestone 3 onward)
signal mission_state_changed(state: String)
signal objective_updated(text: String)
signal extraction_timer_changed(seconds_left: float)
signal docking_available(available: bool)
signal cargo_changed(items: Array)
