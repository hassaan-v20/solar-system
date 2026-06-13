class_name SpaceEnv
extends RefCounted
## Shared "extreme" space look — the nebula sky + heavy post-processing + distant
## suns — reused by the raid and the title screen so the whole game feels cohesive.

static func make_environment() -> Environment:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/space_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1

	# Bloom — punchy, HDR.
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.2
	env.glow_bloom = 0.35
	env.glow_hdr_threshold = 0.9

	# Depth + indirect lighting.
	env.ssao_enabled = true
	env.ssao_radius = 2.5
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.ssr_enabled = true
	env.ssr_max_steps = 48

	# Subtle volumetric haze for light shafts and depth.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_emission = Color(0.05, 0.07, 0.14)
	env.volumetric_fog_emission_energy = 0.35

	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.04, 0.08)
	env.fog_density = 0.0011

	# Colour grade for a cinematic space mood.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.03
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.18
	return env

static func add_suns(parent: Node3D) -> void:
	_sun(parent, Vector3(1.0, 0.45, 0.6), Color(1.0, 0.92, 0.78), 1.7, 30.0)
	_sun(parent, Vector3(-0.7, 0.25, -0.8), Color(0.55, 0.7, 1.0), 0.7, 22.0)
	_sun(parent, Vector3(0.2, -0.55, 0.8), Color(1.0, 0.6, 0.7), 0.5, 18.0)

static func _sun(parent: Node3D, dir: Vector3, col: Color, energy: float, radius: float) -> void:
	var d := dir.normalized()
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	star.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 9.0
	star.material_override = mat
	parent.add_child(star)
	star.global_position = d * 1700.0
	var dl := DirectionalLight3D.new()
	dl.light_color = col
	dl.light_energy = energy
	parent.add_child(dl)
	if absf(d.dot(Vector3.UP)) < 0.98:
		dl.look_at(-d, Vector3.UP)
