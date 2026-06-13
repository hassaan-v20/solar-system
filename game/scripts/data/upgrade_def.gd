class_name UpgradeDef
extends Resource
## Data-layer ship upgrade (GDD §16). Bought once, persists, and modifies one
## ShipDef stat as: new = base * mult + add. Authored as data/upgrades/*.tres.

@export var upgrade_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 200
@export var stat: String = ""        # ShipDef property to modify
@export var mult: float = 1.0
@export var add: float = 0.0
