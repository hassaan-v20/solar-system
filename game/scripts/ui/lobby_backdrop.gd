extends Node3D
## Lobby backdrop (Presentation, client-only): Kestrel Station rendered as a slowly
## rotating 3D scene in the starfield, behind the hub menu (station_ui sits on top).
## Pure visuals — no gameplay. The model is auto-fit from its own bounds, so it needs
## no hand-tuned scale/orient constants.

const STATION_MODEL_PATH := "res://assets/models/station/kestrel_station.glb"
const TARGET_SIZE := 70.0                  # auto-scale so the model's largest dim is ~this
const STATION_OFFSET := Vector3(20, -4, 0) # nudge right, clear of the menu panel on the left
const SPIN_SPEED := 0.06                   # rad/s turntable

var _station: Node3D

func _ready() -> void:
	_build_environment()
	_build_lights()
	_build_station()
	_build_camera()

func _process(delta: float) -> void:
	if _station != null:
		_station.rotate_y(delta * SPIN_SPEED)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/textures/8k_stars_milky_way.jpg")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.20)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.97, 0.92)
	add_child(key)
	# A cool rim from behind so the silhouette reads against the dark.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(20, -140, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.5, 0.7, 1.0)
	add_child(rim)

func _build_station() -> void:
	var scene := load(STATION_MODEL_PATH)
	if not (scene is PackedScene):
		push_warning("lobby station not imported yet: %s" % STATION_MODEL_PATH)
		return
	var pivot := Node3D.new()
	pivot.position = STATION_OFFSET
	var model := (scene as PackedScene).instantiate()
	pivot.add_child(model)
	add_child(pivot)

	# Auto-fit: centre the model on the pivot and scale it to ~TARGET_SIZE, so any
	# model drops in correctly without per-model magic numbers.
	var bounds := _combined_aabb(pivot, model)
	if bounds.size.length() > 0.001:
		model.position = -bounds.get_center()
		var max_dim: float = maxf(maxf(bounds.size.x, bounds.size.y), bounds.size.z)
		pivot.scale = Vector3.ONE * (TARGET_SIZE / max_dim)
	_station = pivot

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.position = STATION_OFFSET + Vector3(0, 16, TARGET_SIZE * 1.9)
	cam.look_at(STATION_OFFSET, Vector3.UP)
	add_child(cam)
	cam.current = true

## Combined AABB of every mesh under `model`, expressed in `space`'s local frame.
func _combined_aabb(space: Node3D, model: Node) -> AABB:
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

func _collect_mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_mesh_instances(c, out)
