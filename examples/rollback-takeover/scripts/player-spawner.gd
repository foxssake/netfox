extends MultiplayerSpawner

@export var spawn_points: Array[Node3D]

var _avatars := {}

func _ready():
	spawn_function = _spawn
	
	NetworkEvents.on_server_start.connect(func(): spawn(1))
	NetworkEvents.on_peer_join.connect(func(peer: int): spawn(peer))
	NetworkEvents.on_peer_leave.connect(func(peer: int): despawn(peer))

func despawn(peer: int) -> void:
	if _avatars.has(peer):
		_avatars[peer].queue_free()
		_avatars.erase(peer)

func _spawn(peer: int) -> Node3D:
	assert(get_spawnable_scene_count() > 0, "No scene configured to spawn!")
	var avatar_scene := load(get_spawnable_scene(0)) as PackedScene
	
	var avatar := avatar_scene.instantiate() as Node3D
	avatar.position = spawn_points.pick_random().global_position
	avatar.name += " #%d" % [peer]
	avatar.set_multiplayer_authority(1)
	
	for child in avatar.find_children("*"):
		if child.is_in_group("Input"):
			child.set_multiplayer_authority(peer)
			
	_avatars[peer] = avatar
	
	return avatar
