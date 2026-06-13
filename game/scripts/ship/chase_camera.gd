class_name ChaseCamera
extends Camera3D
## Smoothed third-person chase camera (Presentation layer, client-only).
## Position lags the ship for a cinematic feel; always frames the ship.

@export var target_path: NodePath
@export var distance: float = 12.0
@export var height: float = 3.5
@export var pos_lerp: float = 6.0

var _target: Node3D

func _ready() -> void:
	top_level = true  # ignore any parent transform; we drive position ourselves
	_target = get_node_or_null(target_path) as Node3D
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

func _desired_position() -> Vector3:
	var t := _target.global_transform
	# basis.z points "backward" in Godot, so this sits behind and above the ship.
	return t.origin + t.basis.z * distance + t.basis.y * height
