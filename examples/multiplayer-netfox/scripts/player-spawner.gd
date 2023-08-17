extends Node

@export var player_scene: PackedScene
@export var spawn_root: Node
@export var spawn_point: Vector3 = Vector3.ZERO

var spawned_for_host: bool = false

func _ready():
	multiplayer.peer_connected.connect(_handle_new_peer)
	multiplayer.connected_to_server.connect(_handle_connected)

func _handle_new_peer(id: int):
	# Spawn an avatar for new player
	_spawn(id)
	
	if not spawned_for_host and multiplayer.is_server():
		# Spawn own avatar on host machine
		# This is a bit cumbersome, as there's no "server started"
		# event, only "connected to server" on the client side
		_spawn(1)
		spawned_for_host = true

func _handle_connected():
	# Spawn an avatar for us
	_spawn(multiplayer.get_unique_id())

func _spawn(id: int):
	var avatar = player_scene.instantiate() as Node3D
	avatar.name += " #%d" % id
	avatar.position = spawn_point
	spawn_root.add_child(avatar)
	avatar.set_multiplayer_authority(id)

	print("Spawned avatar %s at %s" % [avatar.name, multiplayer.get_unique_id()])
