class_name ShipFX
extends Node3D
## Presentation juice (GDD §20) for a ship: twin engine glow, a thruster plume,
## and faint speed dust the ship flies through. Added as a child of a
## ShipController by main._assemble_ship; pure code, no assets.
##
## It only READS ship state, never writes it — so it runs identically on the
## owning peer and on networked puppets. Speed is measured from the ship's own
## position delta (which moves on both via replication), NOT from `velocity`
## (which is only simulated on the owner). The local pilot's `throttle` adds an
## instant flare on top; it stays 0 on puppets, where the speed term carries.

# Engines sit at the rear (the nose is at -Z, so the tail is +Z).
const ENGINE_Z := 1.5   # rear of the scaled model, aligned to its own thruster nozzles
const ENGINE_X := 0.35
const ENGINE_Y := 0.3   # thrusters sit slightly above the hull centre
const IDLE_GLOW := 0.6      # emission energy with no throttle (engines never fully die)
const FULL_GLOW := 7.0      # emission energy at full throttle
const BOOST_GLOW := 11.0    # emission energy while boosting
const ENGINE_COLOR := Color(0.45, 0.85, 1.0)
const DUST_COLOR := Color(0.6, 0.7, 0.85)
const RCS_COLOR := Color(0.85, 0.92, 1.0)   # cold maneuvering-thruster puffs

var engine_color: Color = ENGINE_COLOR   # per-ship tint; set before adding to tree
var _ship: ShipController
var _glow_mats: Array[StandardMaterial3D] = []
var _engine_light: OmniLight3D
var _plume: GPUParticles3D
var _dust: GPUParticles3D
var _rcs: Dictionary = {}         # push-direction -> GPUParticles3D maneuvering thruster
var _level: float = 0.0          # smoothed 0..1+ engine intensity
var _last_pos: Vector3            # for measuring speed from position delta

func _ready() -> void:
	_ship = get_parent() as ShipController
	if _ship != null:
		_last_pos = _ship.global_position
	_build_engines()
	_build_plume()
	_build_dust()
	_build_rcs()

func _process(delta: float) -> void:
	if _ship == null or _ship.ship_def == null or delta <= 0.0:
		return
	# Speed from position delta works for the owner and for replicated puppets
	# alike (both visibly move); `velocity` would read 0 on puppets.
	var pos := _ship.global_position
	var speed := _last_pos.distance_to(pos) / delta
	_last_pos = pos

	var max_sp := maxf(1.0, _ship.ship_def.max_speed)
	var speed_ratio := clampf(speed / max_sp, 0.0, 1.0)
	var boosting := speed > max_sp * 1.05
	# Blend the pilot's actual throttle (instant, local only) with the speed ratio.
	var target := maxf(_ship.throttle, speed_ratio)
	if boosting:
		target = maxf(target, 1.25)
	# Smooth so taps don't strobe the engines.
	_level = lerpf(_level, target, clampf(10.0 * delta, 0.0, 1.0))

	var lit := clampf(_level, 0.0, 1.0)
	var glow := lerpf(IDLE_GLOW, BOOST_GLOW if boosting else FULL_GLOW, lit)
	for mat in _glow_mats:
		mat.emission_energy_multiplier = glow
	if _engine_light != null:
		_engine_light.light_energy = lerpf(0.3, 3.2, lit)
	if _plume != null:
		_plume.amount_ratio = clampf(0.15 + _level, 0.0, 1.0)
	if _dust != null:
		# Dust only fades in once you're actually moving fast, so slow flight stays calm.
		_dust.amount_ratio = smoothstep(0.35, 1.0, speed_ratio)
	_update_rcs()

## Fire each maneuvering thruster in proportion to the ship's lateral/vertical
## thrust this frame (a thruster fires opposite the push, Newton's third law), so
## strafing and flight-assist drift-correction read as little RCS puffs. Owner-only:
## rcs_local is 0 on networked puppets, so they simply show no puffs.
func _update_rcs() -> void:
	if _ship == null:
		return
	var r: Vector3 = _ship.rcs_local
	_set_rcs("right", maxf(0.0, r.x))
	_set_rcs("left", maxf(0.0, -r.x))
	_set_rcs("up", maxf(0.0, r.y))
	_set_rcs("down", maxf(0.0, -r.y))

func _set_rcs(key: String, amount: float) -> void:
	var p: GPUParticles3D = _rcs.get(key)
	if p != null:
		p.amount_ratio = clampf(amount, 0.0, 1.0)

func _build_engines() -> void:
	_engine_light = OmniLight3D.new()
	_engine_light.position = Vector3(0, ENGINE_Y, ENGINE_Z + 0.4)
	_engine_light.light_color = engine_color
	_engine_light.light_energy = 0.4
	_engine_light.omni_range = 9.0
	add_child(_engine_light)

	for sx in [-1.0, 1.0]:
		var bell := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.14
		m.height = 0.28
		bell.mesh = m
		bell.position = Vector3(ENGINE_X * sx, ENGINE_Y, ENGINE_Z)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = engine_color
		mat.emission_enabled = true
		mat.emission = engine_color
		mat.emission_energy_multiplier = IDLE_GLOW
		bell.material_override = mat
		add_child(bell)
		_glow_mats.append(mat)

func _build_plume() -> void:
	_plume = GPUParticles3D.new()
	_plume.position = Vector3(0, ENGINE_Y, ENGINE_Z + 0.3)
	_plume.amount = 90
	_plume.lifetime = 0.55
	_plume.local_coords = false   # plume trails in world space behind the moving ship
	_plume.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var pm := ParticleProcessMaterial.new()
	# Local +Z is the ship's tail, so the exhaust shoots straight out the back.
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 7.0
	pm.initial_velocity_min = 11.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.35
	pm.scale_max = 0.7
	pm.color_ramp = _fade_ramp(Color(0.85, 0.95, 1.0), engine_color)
	_plume.process_material = pm

	var spark := SphereMesh.new()
	spark.radius = 0.1
	spark.height = 0.2
	spark.radial_segments = 5
	spark.rings = 3
	# Unshaded + per-particle vertex color makes the plume self-lit and bright
	# enough to cross the bloom threshold; the ramp tints and fades it out.
	spark.material = _glow_particle_mat()
	_plume.draw_pass_1 = spark
	_plume.emitting = true
	add_child(_plume)

func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.amount = 130
	_dust.lifetime = 1.6
	_dust.local_coords = false   # motes stay put in world; the ship flies through them
	_dust.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 26, 26)   # a cloud the ship sits inside
	pm.direction = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.06
	pm.scale_max = 0.16
	pm.color_ramp = _fade_ramp(DUST_COLOR, DUST_COLOR)
	_dust.process_material = pm

	var mote := SphereMesh.new()
	mote.radius = 0.4
	mote.height = 0.8
	mote.radial_segments = 4
	mote.rings = 2
	mote.material = _glow_particle_mat()
	_dust.draw_pass_1 = mote
	_dust.amount_ratio = 0.0
	_dust.emitting = true
	add_child(_dust)

## Four small maneuvering thrusters. Each is keyed by the push direction it
## produces and mounted on the OPPOSITE side, venting outward — so the "right"
## thruster sits on the left flank and pushes the ship right. _update_rcs flares
## them from the ship's per-axis RCS effort.
func _build_rcs() -> void:
	_rcs["right"] = _make_rcs(Vector3(-0.55, 0.0, -0.5), Vector3(-1, 0, 0))
	_rcs["left"] = _make_rcs(Vector3(0.55, 0.0, -0.5), Vector3(1, 0, 0))
	_rcs["up"] = _make_rcs(Vector3(0.0, -0.4, -0.5), Vector3(0, -1, 0))
	_rcs["down"] = _make_rcs(Vector3(0.0, 0.4, -0.5), Vector3(0, 1, 0))

func _make_rcs(pos: Vector3, dir: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 20
	p.lifetime = 0.28
	p.local_coords = false   # puffs vent into world space as the ship maneuvers
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 14.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.1
	pm.scale_max = 0.24
	pm.color_ramp = _fade_ramp(RCS_COLOR, RCS_COLOR)
	p.process_material = pm

	var spark := SphereMesh.new()
	spark.radius = 0.07
	spark.height = 0.14
	spark.radial_segments = 5
	spark.rings = 3
	spark.material = _glow_particle_mat()
	p.draw_pass_1 = spark
	p.amount_ratio = 0.0
	p.emitting = true
	add_child(p)
	return p

## Unshaded, alpha-blended material that takes its color from each particle's
## color_ramp (delivered as vertex color). Shared shape for plume and dust.
func _glow_particle_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	return mat

## A 3-stop gradient: opaque head → translucent mid → transparent tail. Endpoints
## are set before the midpoint is inserted, so add_point's re-sort can't clobber
## the colors we set by index.
func _fade_ramp(head: Color, tail: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(head.r, head.g, head.b, 1.0))
	g.set_color(1, Color(tail.r, tail.g, tail.b, 0.0))
	g.add_point(0.55, Color(tail.r, tail.g, tail.b, 0.65))
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex
