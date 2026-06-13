class_name WeaponDef
extends Resource
## Data-layer weapon definition (GDD §24.2). Used from Milestone 2.

@export var weapon_id: String = "laser_cannon_mk1"
@export var display_name: String = "Laser Cannon Mk I"
@export var damage: float = 25.0
@export var fire_rate: float = 4.0        # shots per second
@export var heat_per_shot: float = 6.0
@export var max_heat: float = 100.0
@export var cooldown_rate: float = 25.0   # heat dissipated per second
@export var weapon_range: float = 800.0
@export var projectile_speed: float = 200.0
