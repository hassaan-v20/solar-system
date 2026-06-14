class_name ShipLoadoutVisuals
extends RefCounted
## Shared, procedural "what your upgrades look like" parts, used by BOTH the station
## hub backdrop and the real in-game ship. Each upgrade stat maps to one visual
## "category"; build()/attach() assemble one part per owned category onto a ship.
## Sized in model units (for a scale-1.0 hull); attach() scales to the target ship.

const DATACORE_PATH := "res://assets/models/objective/data_core_rack.glb"
const DATACORE_CENTER := Vector3(0.0, 1.157, 0.0)
const SALVAGE_PATH := "res://assets/models/salvage/scifi_crates.glb"
const SALVAGE_CENTER := Vector3(0.0, 0.03, -0.013)

## Which visual category a ShipDef stat belongs to.
static func category_for(stat: String) -> String:
	match stat:
		"hull_max": return "armor"
		"shield_max": return "shield"
		"max_speed", "boost_speed", "acceleration", "boost_accel_mult": return "engine"
		"cargo_slots": return "cargo"
		"turn_speed", "roll_speed", "strafe_accel", "brake_damp", "linear_damp": return "fins"
		"weapon_slots": return "weapon"
		"utility_slots", "repair_kits": return "sensor"
		_: return "engine"

## A container holding one part per distinct owned category (deduped, so two engine
## upgrades don't stack two plumes). all_defs is the list of every UpgradeDef.
static func build(owned_ids: Array, all_defs: Array) -> Node3D:
	var root := Node3D.new()
	var cats := {}
	for id in owned_ids:
		for d in all_defs:
			if d.upgrade_id == id:
				cats[category_for(d.stat)] = true
				break
	for cat in cats:
		var v := make(cat)
		if v != null:
			root.add_child(v)
	return root

## Build the owned visuals and parent them to `ship`, scaled to match its model.
static func attach(ship: Node3D, owned_ids: Array, all_defs: Array, model_scale: float) -> Node3D:
	var holder := build(owned_ids, all_defs)
	holder.scale = Vector3.ONE * model_scale
	ship.add_child(holder)
	return holder

static func make(cat: String) -> Node3D:
	match cat:
		"shield": return _shield()
		"armor": return _armor()
		"engine": return _engine()
		"cargo": return _cargo()
		"fins": return _fins()
		"weapon": return _weapon()
		"sensor": return _sensor()
		_: return null

static func _shield() -> Node3D:
	var n := Node3D.new()
	var s := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 15.0
	sph.height = 30.0
	sph.radial_segments = 32
	sph.rings = 16
	s.mesh = sph
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.3, 0.7, 1.0, 0.10)
	m.emission_enabled = true
	m.emission = Color(0.35, 0.75, 1.0)
	m.emission_energy_multiplier = 0.5
	s.material_override = m
	n.add_child(s)
	return n

static func _armor() -> Node3D:
	var n := Node3D.new()
	for off in [Vector3(0, 2.9, 0), Vector3(0, -2.9, 0)]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(15.0, 0.5, 11.0)
		b.mesh = bm
		b.position = off
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.20, 0.23, 0.28)
		m.metallic = 0.8
		m.roughness = 0.4
		m.emission_enabled = true
		m.emission = Color(0.3, 0.6, 0.85)
		m.emission_energy_multiplier = 0.15
		b.material_override = m
		n.add_child(b)
	return n

static func _engine() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0, 0, -9)   # thrusters sit at the model's -Z end (see main.gd)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.7, 1.0)
	light.light_energy = 4.0
	light.omni_range = 14.0
	n.add_child(light)
	var core := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 1.5
	sp.height = 3.0
	core.mesh = sp
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.6, 0.85, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.8, 1.0)
	m.emission_energy_multiplier = 5.0
	core.material_override = m
	n.add_child(core)
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.6
	p.local_coords = true            # stays with the ship (cheaper, no world trail)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 10.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.3
	pm.scale_max = 0.7
	pm.color = Color(0.5, 0.8, 1.0)
	p.process_material = pm
	var spark := SphereMesh.new()
	spark.radius = 0.25
	spark.height = 0.5
	p.draw_pass_1 = spark
	p.emitting = true
	n.add_child(p)
	return n

static func _cargo() -> Node3D:
	var n := Node3D.new()
	for pos in [Vector3(8, 0, -3), Vector3(-8, 0, -3)]:
		var crate := ModelUtil.spawn(SALVAGE_PATH, 1.6, Vector3.ZERO, SALVAGE_CENTER)
		if crate != null:
			crate.position = pos
			n.add_child(crate)
		else:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(3, 3, 3)
			b.mesh = bm
			b.position = pos
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.6, 0.5, 0.32)
			b.material_override = m
			n.add_child(b)
	return n

static func _fins() -> Node3D:
	var n := Node3D.new()
	for sx in [1.0, -1.0]:
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 3.5, 5.0)
		f.mesh = bm
		f.position = Vector3(8.5 * sx, 2.0, -4.0)
		f.rotation_degrees = Vector3(0, 0, 20.0 * sx)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.3, 0.4)
		m.emission_enabled = true
		m.emission = Color(0.3, 0.8, 1.0)
		m.emission_energy_multiplier = 1.5
		f.material_override = m
		n.add_child(f)
	return n

static func _weapon() -> Node3D:
	# Twin forward cannons (nose is -Z) with glowing muzzles.
	var n := Node3D.new()
	for sx in [1.0, -1.0]:
		var barrel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.6
		cyl.height = 7.0
		barrel.mesh = cyl
		barrel.rotation_degrees = Vector3(90, 0, 0)
		barrel.position = Vector3(5.0 * sx, -0.6, -3.0)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.16, 0.18, 0.22)
		bm.metallic = 0.9
		bm.roughness = 0.35
		barrel.material_override = bm
		n.add_child(barrel)
		var tip := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.55
		sp.height = 1.1
		tip.mesh = sp
		tip.position = Vector3(5.0 * sx, -0.6, -6.6)
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = Color(1.0, 0.6, 0.4)
		tm.emission_enabled = true
		tm.emission = Color(1.0, 0.5, 0.3)
		tm.emission_energy_multiplier = 4.0
		tip.material_override = tm
		n.add_child(tip)
	return n

static func _sensor() -> Node3D:
	var n := Node3D.new()
	var mod := ModelUtil.spawn(DATACORE_PATH, 2.2, Vector3.ZERO, DATACORE_CENTER)
	if mod != null:
		mod.position = Vector3(0, 3.4, 0)
		n.add_child(mod)
	else:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3, 2, 3)
		b.mesh = bm
		b.position = Vector3(0, 3.4, 0)
		n.add_child(b)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.9, 1.0)
	glow.light_energy = 2.5
	glow.omni_range = 12.0
	glow.position = Vector3(0, 3.4, 0)
	n.add_child(glow)
	return n
