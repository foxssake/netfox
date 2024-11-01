extends Node
class_name BrawlerSpawner

@export var player_scene: PackedScene
@export var spawn_root: Node
@export var camera: FollowingCamera
@export var joining_screen: Control
@export var name_input: LineEdit

var spawn_host_avatar: bool = true
var avatars: Dictionary = {}

func _ready():
	NetworkEvents.on_client_start.connect(_handle_connected)
	NetworkEvents.on_server_start.connect(_handle_host)
	NetworkEvents.on_peer_join.connect(_handle_new_peer)
	NetworkEvents.on_peer_leave.connect(_handle_leave)
	NetworkEvents.on_client_stop.connect(_handle_stop)
	NetworkEvents.on_server_stop.connect(_handle_stop)

func _handle_connected(id: int):
	if joining_screen:
		joining_screen.visible = true
	
	# Spawn an avatar for us
	_spawn(id)
	
	if joining_screen:
		await NetworkTime.after_sync
		joining_screen.visible = false

func _handle_host():
	if spawn_host_avatar:
		# Spawn own avatar on host machine
		_spawn(1)

func _handle_new_peer(id: int):
	# Spawn an avatar for new player
	var avatar = _spawn(id)
	
	# Hide avatar until player syncs time
	avatar.visible = false
	while not NetworkTime.is_client_synced(id):
		await NetworkTime.after_client_sync
	avatar.visible = true

func _handle_leave(id: int):
	if not avatars.has(id):
		return
	
	var avatar = avatars[id] as Node
	avatar.queue_free()
	avatars.erase(id)

func _handle_stop():
	# Remove all avatars on game end
	for avatar in avatars.values():
		avatar.queue_free()
	avatars.clear()

func _spawn(id: int) -> BrawlerController:
	var avatar = player_scene.instantiate() as BrawlerController
	avatars[id] = avatar
	avatar.name += " #%d" % id
	avatar.player_id = id
	spawn_root.add_child(avatar)
	
	# Avatar is always owned by server
	avatar.set_multiplayer_authority(1)

	print("Spawned avatar %s at %s" % [avatar.name, multiplayer.get_unique_id()])
	
	# Avatar's input object is owned by player
	var input = avatar.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(id)
		print("Set input(%s) ownership to %s" % [input.name, id])
	
	if id == multiplayer.get_unique_id():
		# If avatar is own, assign it as camera follow target and emit event
		camera.target = avatar
		GameEvents.on_own_brawler_spawn.emit(avatar)
		
		# Submit name
		var player_name = name_input.text
		print("Submitting player name " + player_name)
		_submit_name.rpc(player_name)
	
	return avatar

@rpc("any_peer", "reliable", "call_local")
func _submit_name(player_name: String):
	var pid = multiplayer.get_remote_sender_id()
	var avatar = avatars[pid]
	avatar.player_name = player_name
	print("Setting player name for #%s to %s" % [pid, player_name])
