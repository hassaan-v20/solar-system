extends Node
## Autoload "PlayerProfile": persistent player state (GDD §22.2). Local JSON at
## user://profile.json. Credits, owned upgrades, run stats, and ship damage carry
## between raids — this is the spine of M4's repeatable loop.

# Overridable so unit tests can use a temp file instead of the real profile.
var save_path := "user://profile.json"

var player_id: String = ""
var credits: int = 0
var owned_upgrades: Array[String] = []
var mission_completions: int = 0
var total_cargo_extracted: int = 0
var ship_hull_pct: float = 1.0           # 0..1; persists damage between runs

# Transient (not saved): summary of the last raid, for the results screen.
var last_run: Dictionary = {}

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(save_path):
		_init_new()
		save_profile()
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		_init_new()
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		_init_new()
		return
	player_id = str(data.get("player_id", _new_id()))
	credits = int(data.get("credits", 0))
	owned_upgrades.clear()
	for u in data.get("owned_upgrades", []):
		owned_upgrades.append(str(u))
	mission_completions = int(data.get("mission_completions", 0))
	total_cargo_extracted = int(data.get("total_cargo_extracted", 0))
	ship_hull_pct = clampf(float(data.get("ship_hull_pct", 1.0)), 0.0, 1.0)

func save_profile() -> void:
	var data := {
		"player_id": player_id,
		"credits": credits,
		"owned_upgrades": owned_upgrades,
		"mission_completions": mission_completions,
		"total_cargo_extracted": total_cargo_extracted,
		"ship_hull_pct": ship_hull_pct,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("PlayerProfile: cannot write %s" % save_path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _init_new() -> void:
	player_id = _new_id()
	credits = 0
	owned_upgrades = []
	mission_completions = 0
	total_cargo_extracted = 0
	ship_hull_pct = 1.0

func _new_id() -> String:
	return "pilot-%d" % Time.get_unix_time_from_system()

func has_upgrade(id: String) -> bool:
	return owned_upgrades.has(id)

func can_afford(cost: int) -> bool:
	return credits >= cost

func add_credits(n: int) -> void:
	credits = maxi(0, credits + n)
	EventBus.profile_changed.emit()

## Buys an upgrade if affordable and not already owned. Returns success.
func buy_upgrade(id: String, cost: int) -> bool:
	if has_upgrade(id) or not can_afford(cost):
		return false
	credits -= cost
	owned_upgrades.append(id)
	save_profile()
	EventBus.profile_changed.emit()
	return true

## Repairs to full for the given cost (or free if unaffordable — v0.1 never blocks
## play, GDD §15). Returns the cost actually charged.
func repair(cost: int) -> int:
	var charged := cost if can_afford(cost) else 0
	credits -= charged
	ship_hull_pct = 1.0
	save_profile()
	EventBus.profile_changed.emit()
	return charged
