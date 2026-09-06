extends MultiplayerSpawner
class_name BrawlerSpawner

@export var player_scene: PackedScene
@export var camera: FollowingCamera
@export var joining_screen: Control

var avatars: Dictionary = {}

var _logger := NetfoxLogger.new("fb", "BrawlerSpawner")

func _ready():
	spawn_function = _spawn

	NetworkEvents.on_client_start.connect(_handle_connected)
	NetworkEvents.on_server_start.connect(_handle_host)
	NetworkEvents.on_peer_join.connect(_handle_new_peer)
	NetworkEvents.on_peer_leave.connect(_handle_leave)
	NetworkEvents.on_client_stop.connect(_handle_stop)
	NetworkEvents.on_server_stop.connect(_handle_stop)

func _handle_connected(id: int):
	if joining_screen:
		joining_screen.show()
		await NetworkTime.after_sync
		joining_screen.hide()

func _handle_host():
	if not NetworkBootstrapper.is_dedicated_host():
		# Spawn own avatar on host machine
		spawn(1)

func _handle_new_peer(id: int):
	if not is_multiplayer_authority():
		# Only spawn on server
		return

	# Wait for player to sync time
	while not NetworkTime.is_client_synced(id):
		await NetworkTime.after_client_sync

	# Spawn an avatar for new player
	spawn(id)

func _handle_leave(id: int):
	if not is_multiplayer_authority():
		# Only despawn on server
		return

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

func _spawn(peer_id: int) -> BrawlerController:
	var avatar := player_scene.instantiate() as BrawlerController
	avatars[peer_id] = avatar
	avatar.name += " #%d" % peer_id
	avatar.player_id = peer_id

	# Avatar is always owned by server
	avatar.set_multiplayer_authority(1)

	_logger.info("Spawned avatar %s at %s" % [avatar.name, multiplayer.get_unique_id()])

	# Avatar's input object is owned by player
	var input = avatar.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(peer_id)
		_logger.debug("Set input(%s) ownership to %s" % [input.name, peer_id])

	if peer_id == multiplayer.get_unique_id():
		# If avatar is own, assign it as camera follow target and emit event
		camera.target = avatar
		GameEvents.on_own_brawler_spawn.emit(avatar)

		# Submit name
		var settings := ForestBrawlSettings.get_active()
		var player_name = NameProvider.name() if settings.randomize_name else settings.player_name
		_logger.debug("Submitting player name " + player_name)
		_submit_name.rpc(player_name)

	return avatar

@rpc("any_peer", "reliable", "call_local")
func _submit_name(player_name: String):
	var pid = multiplayer.get_remote_sender_id()
	var avatar = avatars[pid]
	avatar.player_name = player_name
	_logger.debug("Setting player name for #%s to %s" % [pid, player_name])
