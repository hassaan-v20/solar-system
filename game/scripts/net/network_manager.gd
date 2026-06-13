extends Node
## Autoload "Net": ENet host/join for co-op (M5). Host-authoritative; the host is
## peer 1. Plain direct-IP so it works on LAN and over Tailscale with no relay.
## Phase 1 step A: establish the connection + report peers. Scene/ship spawning
## comes in step B.
##
## Headless testing: pass user args after `--`, e.g.
##   godot --headless --path game -- --host
##   godot --headless --path game -- --join=127.0.0.1

signal hosted
signal joined
signal join_failed
signal peers_changed

const DEFAULT_PORT := 7777
const MAX_PEERS := 3        # host + up to 3 clients

var world_seed: int = 0
var active: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_parse_cli()

func host_game(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		push_error("Net: create_server(%d) failed (err %d)" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	world_seed = randi()
	active = true
	print("Net: hosting on :%d (seed %d) as peer %d" % [port, world_seed, multiplayer.get_unique_id()])
	hosted.emit()
	return true

func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Net: create_client(%s:%d) failed (err %d)" % [address, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	print("Net: connecting to %s:%d…" % [address, port])
	return true

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	active = false
	peers_changed.emit()

func is_host() -> bool:
	return active and multiplayer.is_server()

func player_count() -> int:
	return 1 + multiplayer.get_peers().size() if active else 0

func _on_peer_connected(id: int) -> void:
	print("Net: peer %d connected (%d players)" % [id, player_count()])
	peers_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	print("Net: peer %d disconnected" % id)
	peers_changed.emit()

func _on_connected_to_server() -> void:
	active = true
	print("Net: connected to host as peer %d" % multiplayer.get_unique_id())
	joined.emit()

func _on_connection_failed() -> void:
	print("Net: connection failed")
	multiplayer.multiplayer_peer = null
	join_failed.emit()

func _on_server_disconnected() -> void:
	print("Net: host disconnected")
	leave()

func _parse_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			call_deferred("host_game")
		elif arg.begins_with("--join="):
			call_deferred("join_game", arg.substr("--join=".length()))
