class_name PlanetBackdrop
extends Node3D
## A distant planet rendered as a backdrop (Presentation). Keeps both the 1K and 4K
## Phoenix models and picks the one the scenario needs: from how prominent the planet
## will look (apparent size = radius / distance to the viewer), a tiny speck loads
## 1K and a hero planet loads 4K. `quality` can force LOW/HIGH. No collision; it's
## a far, unreachable backdrop. Set radius / position / viewer / quality before
## adding to the tree (the model is chosen and fit in _ready).

const HI_RES_APPARENT := 0.12   # radius/distance above this → prominent enough to want 4K

enum Quality { AUTO, LOW, HIGH }

# Model paths (default = Phoenix). Set these to reuse for Earth, the galaxy, etc.
# For a single-res model (e.g. the galaxy) point both at the same file + quality LOW.
@export var model_1k: String = "res://assets/models/planets/planet_phoenix_1k.glb"
@export var model_4k: String = "res://assets/models/planets/planet_phoenix_4k.glb"
@export var radius: float = 700.0
@export var quality: int = Quality.AUTO
@export var spin_speed: float = 0.008
var viewer: Vector3 = Vector3.ZERO   # reference viewpoint for the AUTO decision (player spawn)

var _model: Node3D

func _ready() -> void:
	var hi := _use_high()
	var path := model_4k if hi else model_1k
	var scene := load(path)
	if not (scene is PackedScene):
		push_warning("planet not imported yet: %s" % path)
		return
	_model = (scene as PackedScene).instantiate()
	add_child(_model)
	# Auto-fit: centre on this node and scale so the world radius matches `radius`.
	var ab := ModelUtil.combined_aabb(self, _model)
	if ab.size.length() > 0.001:
		_model.position = -ab.get_center()
		var max_dim: float = maxf(maxf(ab.size.x, ab.size.y), ab.size.z)
		scale = Vector3.ONE * (2.0 * radius / max_dim)
	print("PlanetBackdrop: %s (apparent %.3f, r=%.0f)" % ["4K" if hi else "1K", _apparent(), radius])

func _process(delta: float) -> void:
	if _model != null and spin_speed != 0.0:
		rotate_y(delta * spin_speed)

func _apparent() -> float:
	return radius / maxf(1.0, global_position.distance_to(viewer))

func _use_high() -> bool:
	match quality:
		Quality.HIGH:
			return true
		Quality.LOW:
			return false
		_:
			return _apparent() >= HI_RES_APPARENT
