class_name CargoSystem
extends Node
## Simulation: what the ship is carrying this run (GDD §14). Minimal for M3 — the
## Data Core, and later salvage. Credits/persistence arrive in M4.

var items: Array[String] = []

func add_item(id: String) -> void:
	items.append(id)
	EventBus.cargo_changed.emit(items.duplicate())

func has_item(id: String) -> bool:
	return items.has(id)
