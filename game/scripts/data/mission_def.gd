class_name MissionDef
extends Resource
## Data-layer mission definition (GDD §5.1, §24). Authored as data/missions/*.tres.
## The MissionManager reads these numbers; nothing is hardcoded (GDD §30.3).

@export var mission_id: String = "ghost_station"
@export var display_name: String = "Ghost Station"
@export var station_distance: float = 240.0      # derelict station's distance ahead of spawn
@export var extraction_distance: float = 260.0    # how far the extraction point appears
@export var hack_duration: float = 25.0           # seconds to retrieve the Data Core
@export var extract_duration: float = 75.0        # meltdown countdown once hacked
@export var hack_wave_size: int = 3               # drones per wave during the hack
@export var extract_wave_size: int = 2            # drones per wave during extraction
@export var wave_interval: float = 12.0           # seconds between waves
@export var reward_credits: int = 500             # awarded on success (economy lands in M4)
