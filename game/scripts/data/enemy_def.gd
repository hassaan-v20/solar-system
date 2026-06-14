class_name EnemyDef
extends Resource
## Data-layer enemy definition (GDD §24.3). Authored as data/enemies/*.tres.
## Controllers read these numbers; nothing is hardcoded (GDD §30.3).

@export var enemy_id: String = "light_drone"
@export var display_name: String = "Light Drone"
@export var hull_max: float = 60.0
@export var move_speed: float = 26.0         # top cruise speed it accelerates toward
@export var accel: float = 18.0              # thrust accel (m/s²) — gives the drone momentum
@export var turn_speed: float = 2.6          # rad/s slewed toward the lead point
@export var preferred_range: float = 42.0    # distance it tries to hold
@export var weapon_damage: float = 9.0
@export var fire_rate: float = 1.0           # shots per second
@export var projectile_speed: float = 120.0
@export var score_value: int = 100
