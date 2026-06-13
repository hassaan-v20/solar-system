class_name UpgradeSystem
extends RefCounted
## Applies owned upgrades to a base ShipDef, returning an outfitted copy so the
## base .tres stays immutable (GDD §16). Pure logic — unit-tested.

const UPGRADE_DIR := "res://data/upgrades/"

## Every upgrade defined in data/upgrades, cheapest first.
static func all_upgrades() -> Array[UpgradeDef]:
	var defs: Array[UpgradeDef] = []
	var dir := DirAccess.open(UPGRADE_DIR)
	if dir == null:
		return defs
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var d: Resource = load(UPGRADE_DIR + file)
			if d is UpgradeDef:
				defs.append(d)
	defs.sort_custom(func(a: UpgradeDef, b: UpgradeDef) -> bool: return a.cost < b.cost)
	return defs

## Base def + the player's owned upgrade ids -> a new, outfitted ShipDef.
static func outfit(base: ShipDef, owned_ids: Array) -> ShipDef:
	var out: ShipDef = base.duplicate()
	for def in all_upgrades():
		if owned_ids.has(def.upgrade_id):
			_apply(out, def)
	return out

## Test-friendly: apply an explicit list of UpgradeDefs (no disk access).
static func apply_list(base: ShipDef, defs: Array) -> ShipDef:
	var out: ShipDef = base.duplicate()
	for def in defs:
		_apply(out, def)
	return out

static func _apply(out: ShipDef, def: UpgradeDef) -> void:
	if def.stat == "" or not (def.stat in out):
		return
	out.set(def.stat, float(out.get(def.stat)) * def.mult + def.add)
