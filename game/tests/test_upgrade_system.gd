extends GutTest
## UpgradeSystem: stat math (new = base*mult + add), base immutability, catalog.

func _upg(stat: String, mult: float, add: float) -> UpgradeDef:
	var u := UpgradeDef.new()
	u.stat = stat
	u.mult = mult
	u.add = add
	return u

func test_multiplicative_upgrade() -> void:
	var base := ShipDef.new()        # hull_max default 1000
	var out := UpgradeSystem.apply_list(base, [_upg("hull_max", 1.15, 0.0)])
	assert_almost_eq(out.hull_max, 1150.0, 0.01)

func test_additive_upgrade() -> void:
	var base := ShipDef.new()        # cargo_slots default 6
	var out := UpgradeSystem.apply_list(base, [_upg("cargo_slots", 1.0, 2.0)])
	assert_eq(out.cargo_slots, 8)

func test_base_def_not_mutated() -> void:
	var base := ShipDef.new()
	UpgradeSystem.apply_list(base, [_upg("hull_max", 2.0, 0.0)])
	assert_almost_eq(base.hull_max, 1000.0, 0.01, "base ShipDef stays immutable")

func test_unknown_stat_ignored() -> void:
	var base := ShipDef.new()
	var out := UpgradeSystem.apply_list(base, [_upg("does_not_exist", 9.0, 9.0)])
	assert_almost_eq(out.hull_max, 1000.0, 0.01)

func test_catalog_loads_from_disk() -> void:
	assert_eq(UpgradeSystem.all_upgrades().size(), 4, "four upgrade defs in data/upgrades")
