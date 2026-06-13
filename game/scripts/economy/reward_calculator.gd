class_name RewardCalculator
extends RefCounted
## Pure mission-payout logic (GDD §15). Takes plain values, returns credits — no
## engine state, so it is cheap to unit-test.

const PER_DRONE := 25            # drone loot
const DATA_CORE_VALUE := 300     # cargo sale of the recovered Data Core
const FAIL_CONSOLATION := 50     # a little something so a failed run isn't a total loss

# Repair cost tiers by remaining hull (GDD §15.2).
const REPAIR_MINOR := 100
const REPAIR_MEDIUM := 300
const REPAIR_HEAVY := 600
const REPAIR_DESTROYED := 1000

static func compute(success: bool, drones_killed: int, has_data_core: bool, base_reward: int) -> int:
	var credits := PER_DRONE * maxi(0, drones_killed)
	if success:
		credits += base_reward
		if has_data_core:
			credits += DATA_CORE_VALUE
	else:
		credits += FAIL_CONSOLATION
	return credits

## Credits to repair to full, by remaining hull fraction (0..1).
static func repair_cost(hull_pct: float) -> int:
	if hull_pct <= 0.0:
		return REPAIR_DESTROYED
	if hull_pct >= 0.99:
		return 0
	if hull_pct >= 0.66:
		return REPAIR_MINOR
	if hull_pct >= 0.33:
		return REPAIR_MEDIUM
	return REPAIR_HEAVY
