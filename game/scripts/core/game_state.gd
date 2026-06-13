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
	_setup_fullscreen_toggle()
	_setup_ui_pad()

# Godot's default ui_up/down/left/right include joypad mappings, but ui_accept /
# ui_cancel do NOT — so menus navigate with the D-pad yet ✕ won't select. Add the
# DualSense face buttons here (globally, before any scene) to fix that.
func _setup_ui_pad() -> void:
	var cross := InputEventJoypadButton.new()
	cross.button_index = JOY_BUTTON_A           # ✕ — confirm/select
	InputMap.action_add_event("ui_accept", cross)
	var circle := InputEventJoypadButton.new()
	circle.button_index = JOY_BUTTON_B          # ○ — back/cancel
	InputMap.action_add_event("ui_cancel", circle)

# Global fullscreen toggle (works on title, station, and in-raid). The game
# launches fullscreen via project.godot; this lets you drop back to a window.
func _setup_fullscreen_toggle() -> void:
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F11
	InputMap.action_add_event("toggle_fullscreen", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK          # DualSense Create / Share button
	InputMap.action_add_event("toggle_fullscreen", pad)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if is_fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

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
