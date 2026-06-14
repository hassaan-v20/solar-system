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

## Combined AABB of every mesh under `model`, expressed in `space`'s local frame.
## Both must already be in the tree (uses global transforms). Used to auto-fit an
## imported model to a target size without per-model magic numbers.
static func combined_aabb(space: Node3D, model: Node) -> AABB:
	var meshes: Array = []
	_collect_mesh_instances(model, meshes)
	var inv := space.global_transform.affine_inverse()
	var out := AABB()
	var first := true
	for mi in meshes:
		var inst := mi as MeshInstance3D
		var ab := inst.get_aabb()
		var rel := inv * inst.global_transform
		for i in 8:
			var corner := ab.position + Vector3(
				ab.size.x if (i & 1) != 0 else 0.0,
				ab.size.y if (i & 2) != 0 else 0.0,
				ab.size.z if (i & 4) != 0 else 0.0)
			var p := rel * corner
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out

static func _collect_mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_mesh_instances(c, out)

## Give every mesh under `model` a trimesh StaticBody on `layer`, turning the
## visible geometry solid. Trimesh follows the real hull so openings stay flyable.
static func add_trimesh_collision(model: Node, layer: int) -> void:
	var meshes: Array = []
	_collect_mesh_instances(model, meshes)
	for mi in meshes:
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		col.shape = inst.mesh.create_trimesh_shape()
		body.add_child(col)
		inst.add_child(body)
