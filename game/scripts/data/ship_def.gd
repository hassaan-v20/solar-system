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

# Flight feel — full Newtonian rigid-body model (see ShipController). Thrust and
# steering are accelerations applied to conserved momentum; space has no drag, so
# the ship coasts. Speed bleeds off only via the brake or flight assist.
@export var mass: float = 8.0                   # rigid-body mass (drives collision momentum)
@export var acceleration: float = 32.0          # forward main-engine thrust (m/s²)
@export var reverse_accel: float = 16.0         # reverse thrust — weaker than forward (realistic)
@export var strafe_accel: float = 20.0          # RCS lateral + vertical thrust (m/s²)
@export var boost_accel_mult: float = 1.8
@export var assist_response: float = 3.0        # how hard flight assist pulls uncommanded drift to rest (1/s)
@export var assist_decel: float = 34.0          # RCS decel budget the assist may spend (m/s²)
@export var brake_decel: float = 60.0           # active brake (Ctrl): a firm all-axis stop (m/s²)
@export var flight_assist_default: bool = true  # start assisted (coupled); off = raw Newtonian drift
@export var turn_rate: float = 2.4              # max pitch/yaw rate (rad/s)
@export var roll_rate: float = 2.8              # max roll rate (rad/s)
@export var turn_accel: float = 7.0             # angular accel toward the commanded rate (rad/s²)
@export var rot_assist: float = 5.0             # angular decel the assist spends to kill unwanted spin (rad/s²)
@export var mouse_sens: float = 0.05            # mouse pixels → commanded turn rate
