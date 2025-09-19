extends Node
class_name SceneSpawner

## Spawns/Despawns new scenes with the latest properties over network.
##
## This node is designed to use only on the host.

## The root node, is used to fetch properties and ensure root is ready.
@export var root : Node = null

## Properties to record and use on spawn.
@export var properties: Array[String]

## If true, [SceneSpawner] will spawn this scene on all peers with properties fetched.
## Keep in mind that to fetch properties, [SceneSpawner] waits root nodes ready if not. 
@export var replicate_on_spawn : bool = false

## If true, [SceneSpawner] will despawn this scene on all peers.
## If replicate_on_spawn is false, setting this to true will still despawn on
## peers which have remote spawned node.
@export var replicate_on_despawn : bool = false

## File path to the current scene, must be configured manually.
@export_file_path("*.tscn") var scene_path = ""

# Array list of peers which this node is spawned remotely.
# Used to automaticly despawn when this node exits tree.
var _replicated_peers : Array[int] = []

# Ensure root is ready, get_snapshot then replicate spawn to peers if enabled. 
func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	
	if not replicate_on_spawn:
		return
	
	if root.is_node_ready():
		var absolute_node_path := root.get_parent().get_path()
		NetworkSceneSpawner._spawn.rpc(scene_path, absolute_node_path, _get_snapshot())

# Replicate despawn to all peers if enabled.
# Replicate despawn to [member SceneSpawner._replicated_peers] always.
func _exit_tree() -> void:
	var absolute_node_path := root.get_path()
	
	if replicate_on_despawn:
		NetworkSceneSpawner._despawn.rpc(absolute_node_path)
	else:
		# Despawn on replicated peers. See member spawn_on_peer.
		for peer_id : int in _replicated_peers:
			NetworkSceneSpawner._despawn.rpc_id(peer_id, absolute_node_path)

## Spawn on specific peer with current properties.
## Spawned peer id will be remembered and automaticly despawned if 
## [member SceneSpawner.replicate_on_despawn] is true.
func spawn_on_peer(peer_id : int) -> void:
	var absolute_node_path := root.get_parent().get_path()
	NetworkSceneSpawner._spawn.rpc_id(peer_id, scene_path, absolute_node_path, _get_snapshot())
	
	_replicated_peers.push_back(peer_id)

## Despawn on specific peer.
## If given [param peer_id] was not replicated before, this function will return without despawning.
func despawn_on_peer(peer_id : int) -> void:
	if not _replicated_peers.has(peer_id):
		return
	
	var absolute_node_path := root.get_path()
	NetworkSceneSpawner._despawn.rpc_id(peer_id, absolute_node_path)
	_replicated_peers.erase(peer_id)

# Get current snapshot as Dictionary.
func _get_snapshot() -> Dictionary:
	var dict := {}
	
	for property : String in properties:
		var value = root.get_indexed(property)
		dict[property] = value
	
	return dict

# If disconnected peer_id was in the list [member SceneSpawner._replicated_peers], erase it.
func _on_multiplayer_peer_disconnected(peer_id : int) -> void:
	# Just try to erase without checking if its there.
	_replicated_peers.erase(peer_id)
