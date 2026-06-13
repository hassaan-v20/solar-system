extends GutTest
## PlayerProfile: buy/repair rules and JSON save/load round-trip. Runs on a
## throwaway file (save_path override) so the real profile is never touched.

const TMP := "user://test_profile.json"

var _p

func before_each() -> void:
	_clear_tmp()
	_p = load("res://scripts/economy/player_profile.gd").new()
	_p.save_path = TMP
	add_child_autofree(_p)        # _ready -> load_profile: no file -> fresh profile

func after_all() -> void:
	_clear_tmp()

func _clear_tmp() -> void:
	var d := DirAccess.open("user://")
	if d != null and d.file_exists("test_profile.json"):
		d.remove("test_profile.json")

func test_starts_with_zero_credits() -> void:
	assert_eq(_p.credits, 0)

func test_buy_deducts_and_grants() -> void:
	_p.credits = 500
	assert_true(_p.buy_upgrade("hull_plating_1", 300))
	assert_eq(_p.credits, 200)
	assert_true(_p.has_upgrade("hull_plating_1"))

func test_cannot_rebuy_owned() -> void:
	_p.credits = 1000
	_p.buy_upgrade("hull_plating_1", 300)
	assert_false(_p.buy_upgrade("hull_plating_1", 300), "owned upgrade can't be re-bought")
	assert_eq(_p.credits, 700)

func test_cannot_buy_when_unaffordable() -> void:
	_p.credits = 100
	assert_false(_p.buy_upgrade("hull_plating_1", 300))
	assert_eq(_p.credits, 100)
	assert_false(_p.has_upgrade("hull_plating_1"))

func test_save_load_round_trip() -> void:
	_p.credits = 1234
	var ups: Array[String] = ["hull_plating_1", "cargo_rack_1"]
	_p.owned_upgrades = ups
	_p.mission_completions = 3
	_p.ship_hull_pct = 0.42
	_p.save_profile()

	var q = load("res://scripts/economy/player_profile.gd").new()
	q.save_path = TMP
	add_child_autofree(q)         # _ready -> load_profile reads what we saved
	assert_eq(q.credits, 1234)
	assert_eq(q.owned_upgrades.size(), 2)
	assert_true(q.has_upgrade("cargo_rack_1"))
	assert_eq(q.mission_completions, 3)
	assert_almost_eq(q.ship_hull_pct, 0.42, 0.001)

func test_repair_restores_full_and_charges() -> void:
	_p.credits = 500
	_p.ship_hull_pct = 0.5
	var charged: int = _p.repair(RewardCalculator.repair_cost(0.5))  # medium = 300
	assert_eq(charged, 300)
	assert_eq(_p.credits, 200)
	assert_almost_eq(_p.ship_hull_pct, 1.0, 0.001)

func test_free_basic_repair_when_broke() -> void:
	_p.credits = 50
	_p.ship_hull_pct = 0.0
	var charged: int = _p.repair(RewardCalculator.repair_cost(0.0))  # destroyed = 1000, unaffordable
	assert_eq(charged, 0, "free basic repair when broke (v0.1 never blocks play)")
	assert_eq(_p.credits, 50)
	assert_almost_eq(_p.ship_hull_pct, 1.0, 0.001)
