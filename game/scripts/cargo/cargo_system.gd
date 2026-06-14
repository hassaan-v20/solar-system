class_name CargoSystem
extends Node
## Simulation: what the ship is carrying this run (GDD §14). Minimal for M3 — the
## Data Core, and later salvage. Credits/persistence arrive in M4.

var items: Array[String] = []
var max_slots: int = 6          # hold capacity; set from ShipDef.cargo_slots
var salvage_value: int = 0      # total credit value of salvage aboard (banked on extract)

func add_item(id: String) -> void:
	# Objective items (the Data Core) always fit — they're not capped by salvage slots.
	items.append(id)
	EventBus.cargo_changed.emit(items.duplicate())

## Tries to load a salvage crate; returns false (hold full) so the caller can leave
## the crate floating. This is what makes the hold a real "what do I carry?" choice.
func add_salvage(id: String, value: int) -> bool:
	if is_full():
		return false
	items.append(id)
	salvage_value += value
	EventBus.cargo_changed.emit(items.duplicate())
	return true

func has_item(id: String) -> bool:
	return items.has(id)

func slots_used() -> int:
	return items.size()

func is_full() -> bool:
	return items.size() >= max_slots
