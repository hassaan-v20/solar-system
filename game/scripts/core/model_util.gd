class_name ModelUtil
extends RefCounted
## Shared GLB loader. Instantiates an imported model under a pivot that scales and
## rotates it, with a recenter child that cancels the model's origin offset (so its
## bounding-box centre sits at the returned node's origin). Returns null if the
## model hasn't been imported yet — every caller falls back gracefully.

static func spawn(path: String, model_scale: float, euler: Vector3, center: Vector3) -> Node3D:
	var scene := load(path)
	if not (scene is PackedScene):
		push_warning("model not imported yet: %s" % path)
		return null
	var pivot := Node3D.new()
	pivot.scale = Vector3.ONE * model_scale
	pivot.rotation_degrees = euler
	var recenter := Node3D.new()
	recenter.position = -center
	recenter.add_child((scene as PackedScene).instantiate())
	pivot.add_child(recenter)
	return pivot
