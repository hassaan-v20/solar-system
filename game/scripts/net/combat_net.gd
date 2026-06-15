class_name CombatNet
extends Node
## Host-authoritative projectiles. Weapons call fire(); in solo the bolt spawns
## locally and damages, in co-op the host spawns it (replicated to all peers via a
## MultiplayerSpawner) and ONLY the host's copy deals damage — clients get a
## visual-only bolt. Bolts fly straight at constant speed, so each peer simulates
## the motion identically from the spawn data; no per-frame sync needed.
##
## Found by WeaponController via the "combat_net" group. Add one per combat scene.

var _root: Node3D
var _spawner: MultiplayerSpawner

func _ready() -> void:
	add_to_group("combat_net")
	_root = Node3D.new()
	_root.name = "Projectiles"
	add_child(_root)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "BoltSpawner"   # stable path so host-spawned bolts replicate to clients
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_root)
	_spawner.spawn_function = _spawn_from_data

## Called by a WeaponController when it fires. xform = muzzle frame (basis + origin).
func fire(xform: Transform3D, inherited_velocity: Vector3, damage: float, mask: int, color: Color, speed: float) -> void:
	var data := {
		"o": xform.origin,
		"q": xform.basis.get_rotation_quaternion(),
		"v": inherited_velocity,
		"d": damage, "m": mask, "s": speed, "c": color,
	}
	if not Net.active:
		_root.add_child(_build(data, true))      # solo: local + damaging
	elif multiplayer.is_server():
		_spawner.spawn(data)                     # host: replicated to all
	else:
		_request_fire.rpc_id(1, data)            # client: ask the host to spawn it

@rpc("any_peer", "call_remote", "reliable")
func _request_fire(data: Dictionary) -> void:
	if multiplayer.is_server():
		_spawner.spawn(data)

## Runs on every peer (via the spawner). Only the host's copy is damaging; clients
## get a visual-only bolt (no collision), kept in sync by deterministic motion.
func _spawn_from_data(data: Dictionary) -> Node:
	return _build(data, multiplayer.is_server())

func _build(data: Dictionary, damaging: bool) -> Projectile:
	var bolt := Projectile.new()
	bolt.setup(float(data["d"]), float(data["s"]), int(data["m"]), data["c"])
	bolt.inherited_velocity = data["v"]
	bolt.damaging = damaging
	bolt.transform = Transform3D(Basis(data["q"]), data["o"])
	return bolt
