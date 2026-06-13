extends GutTest
## Pure mission-payout + repair-cost logic (RewardCalculator).

func test_success_with_core_and_drones() -> void:
	# base 500 + core 300 + 4 drones * 25 = 900
	assert_eq(RewardCalculator.compute(true, 4, true, 500), 900)

func test_success_without_core() -> void:
	# base 500 + 2 drones * 25 = 550
	assert_eq(RewardCalculator.compute(true, 2, false, 500), 550)

func test_failure_pays_consolation_plus_drone_loot() -> void:
	# fail ignores base + core: 50 consolation + 3 * 25 = 125
	assert_eq(RewardCalculator.compute(false, 3, true, 500), 125)

func test_negative_drone_count_is_clamped() -> void:
	assert_eq(RewardCalculator.compute(true, -5, false, 500), 500)

func test_repair_cost_tiers() -> void:
	assert_eq(RewardCalculator.repair_cost(1.0), 0, "full hull is free")
	assert_eq(RewardCalculator.repair_cost(0.8), RewardCalculator.REPAIR_MINOR)
	assert_eq(RewardCalculator.repair_cost(0.5), RewardCalculator.REPAIR_MEDIUM)
	assert_eq(RewardCalculator.repair_cost(0.1), RewardCalculator.REPAIR_HEAVY)
	assert_eq(RewardCalculator.repair_cost(0.0), RewardCalculator.REPAIR_DESTROYED)
