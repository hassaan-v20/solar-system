extends Node
## Persistent meta-game state (autoload "GameState"). Credits, ship upgrades, and
## lifetime stats survive between raids and across sessions (saved to user://).
## Also carries the chosen contract and last-raid result across scene changes.

const SAVE_PATH := "user://profile.cfg"

const MISSIONS := [
	"res://data/missions/ghost_station.tres",
	"res://data/missions/salvage_run.tres",
	"res://data/missions/last_stand.tres",
	"res://data/missions/bounty_hunt.tres",
	"res://data/missions/deep_core.tres",
]

const UPGRADES := {
	"hull":    {"name": "Hull Plating",     "base": 300},
	"shield":  {"name": "Shield Capacitor", "base": 300},
	"weapon":  {"name": "Laser Tuning",     "base": 350},
	"engine":  {"name": "Engine Boost",     "base": 280},
	"missile": {"name": "Missile Rack",     "base": 400},
}

var credits: int = 500
var upgrades := {"hull": 0, "shield": 0, "weapon": 0, "engine": 0, "missile": 0}
var stats := {"raids": 0, "wins": 0, "earned": 0}

var selected_mission: String = MISSIONS[0]
var last_result := {}        # {name, success, reward}

func _ready() -> void:
	load_profile()

func cost(key: String) -> int:
	return int(UPGRADES[key].base * pow(1.6, upgrades[key]))

func buy(key: String) -> bool:
	var c := cost(key)
	if credits >= c:
		credits -= c
		upgrades[key] += 1
		save_profile()
		return true
	return false

func apply_ship(sd: ShipDef) -> void:
	sd.hull_max += 200.0 * upgrades.hull
	sd.shield_max += 120.0 * upgrades.shield
	sd.max_speed += 6.0 * upgrades.engine
	sd.boost_speed += 9.0 * upgrades.engine
	sd.acceleration += 4.0 * upgrades.engine

func apply_weapon(wd: WeaponDef) -> void:
	wd.damage += 6.0 * upgrades.weapon
	wd.fire_rate += 0.4 * upgrades.weapon

func missile_bonus() -> int:
	return 2 * upgrades.missile

func grant_reward(success: bool, reward: int, mission_name: String) -> void:
	var earned := reward if success else int(reward * 0.25)
	credits += earned
	stats.raids += 1
	if success:
		stats.wins += 1
	stats.earned += earned
	last_result = {"name": mission_name, "success": success, "reward": earned}
	save_profile()

func clear_result() -> void:
	last_result = {}

# ── persistence ───────────────────────────────────────────────────────────────
func save_profile() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "credits", credits)
	cf.set_value("p", "upgrades", upgrades)
	cf.set_value("p", "stats", stats)
	cf.save(SAVE_PATH)

func load_profile() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	credits = cf.get_value("p", "credits", credits)
	var u = cf.get_value("p", "upgrades", upgrades)
	for k in upgrades:
		if u.has(k):
			upgrades[k] = u[k]
	var s = cf.get_value("p", "stats", stats)
	for k in stats:
		if s.has(k):
			stats[k] = s[k]
