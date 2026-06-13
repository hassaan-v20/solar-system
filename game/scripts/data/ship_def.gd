class_name ShipDef
extends Resource
## Data-layer ship definition (GDD §24.1). Authored as data/ships/*.tres.
## Controllers read these numbers; nothing is hardcoded (GDD §30.3).

# Core stats (mirror the GDD JSON schema)
@export var ship_id: String = "wayfarer"
@export var display_name: String = "Wayfarer"
@export var hull_max: float = 1000.0
@export var shield_max: float = 500.0
@export var cargo_slots: int = 6
@export var max_speed: float = 42.0
@export var boost_speed: float = 70.0
@export var weapon_slots: int = 2
@export var utility_slots: int = 1
@export var repair_kits: int = 3

# Flight feel (arcade tuning — not in the GDD JSON, needed for game feel)
@export var acceleration: float = 30.0
@export var strafe_accel: float = 22.0
@export var linear_damp: float = 0.8
@export var brake_damp: float = 3.0
@export var turn_speed: float = 2.5
@export var roll_speed: float = 2.8
@export var boost_accel_mult: float = 1.8
