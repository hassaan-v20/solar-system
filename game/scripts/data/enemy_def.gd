class_name EnemyDef
extends Resource
## Data-layer enemy definition (GDD §24). Authored as data/enemies/*.tres.

@export var enemy_id: String = "light_drone"
@export var display_name: String = "Light Drone"
@export var hull_max: float = 60.0
@export var move_speed: float = 28.0
@export var accel: float = 24.0
@export var preferred_range: float = 70.0      # tries to hover around this distance
@export var aggro_range: float = 320.0
@export var damage: float = 12.0               # per projectile
@export var fire_rate: float = 0.8             # shots per second
@export var projectile_speed: float = 140.0
@export var score: int = 100
@export var body_color: Color = Color(0.9, 0.35, 0.30)
