class_name MissionDef
extends Resource
## Data-layer mission definition (GDD §"contracts"). Authored as data/missions/*.tres.
## One MissionDef drives the whole raid loop in mission_manager.gd.

@export var mission_id: String = "ghost_station"
@export var display_name: String = "Ghost Station"
@export_enum("hack", "salvage", "defend", "bounty") var mission_type: String = "hack"

@export var hold_time: float = 8.0          # hack/defend seconds
@export var extract_time: float = 70.0      # extraction window
@export var target_count: int = 3           # salvage caches / bounty kills
@export var reward: int = 1000

# Difficulty knobs.
@export var start_enemies: int = 5          # enemies at mission start
@export var reinforce: int = 3              # enemies per reinforcement burst
@export var reinforce_gap: float = 11.0     # seconds between reinforcements
@export var extract_reinforce: int = 6      # extra enemies when extraction begins
