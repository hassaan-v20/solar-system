class_name ChaseCamera
extends Camera3D
## Smoothed third-person chase camera (Presentation layer, client-only).
## Position lags the ship for a cinematic feel; always frames the ship.

@export var target_path: NodePath
@export var distance: float = 12.0
@export var height: float = 3.5
@export var pos_lerp: float = 6.0
# Speed-based FOV: widening the view as the ship nears top speed reads as
# acceleration. Pure presentation — it reads sim state but never writes it.
@export var base_fov: float = 72.0
@export var boost_fov: float = 88.0
@export var fov_lerp: float = 4.0

var _target: Node3D
var _ship: ShipController
var _shake: float = 0.0

func _ready() -> void:
	top_level = true  # ignore any parent transform; we drive position ourselves
	_target = get_node_or_null(target_path) as Node3D
	_ship = _target as ShipController
	fov = base_fov
	far = 8000.0   # reach far enough to render distant backdrops (e.g. the planet)
	EventBus.ship_hit.connect(_on_ship_hit)
	if _target != null:
		global_position = _desired_position()  # snap behind the ship on frame 1

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	global_position = global_position.lerp(_desired_position(), clampf(pos_lerp * delta, 0.0, 1.0))
	var target_pos := _target.global_position
	# Guard against look_at erroring when camera and ship momentarily coincide.
	if global_position.distance_to(target_pos) > 0.01:
		look_at(target_pos, _target.global_transform.basis.y)
	_update_fov(delta)
	_apply_shake(delta)

func _on_ship_hit(amount: float) -> void:
	_shake = minf(0.7, _shake + amount * 0.012)

func _apply_shake(delta: float) -> void:
	if _shake <= 0.001:
		return
	# Jitter position only (orientation stays on the ship); smoothing pulls it back.
	global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	_shake = lerpf(_shake, 0.0, clampf(9.0 * delta, 0.0, 1.0))

func _update_fov(delta: float) -> void:
	if _ship == null or _ship.ship_def == null:
		return
	var ratio := clampf(_ship.get_speed() / _ship.ship_def.boost_speed, 0.0, 1.0)
	var want := lerpf(base_fov, boost_fov, ratio)
	fov = lerpf(fov, want, clampf(fov_lerp * delta, 0.0, 1.0))

func _desired_position() -> Vector3:
	var t := _target.global_transform
	# basis.z points "backward" in Godot, so this sits behind and above the ship.
	return t.origin + t.basis.z * distance + t.basis.y * height
