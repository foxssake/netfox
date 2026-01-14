extends Node
class_name _NetworkSceneSpawner

## Singleton that spawns/despawns scenes with [SceneSpawner] helper node on clients.

# Preloaded scenes can be passed to avoid loading scenes on runtime.
# See [method _NetworkSceneSpawner.set_preloaded_scenes].
var _preloaded_scenes : Dictionary[String, PackedScene] = {}

# Netfox logger.
static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NetworkSceneSpawner")

## Set preloaded scenes with given param scenes.
func set_preloaded_scenes(scenes : Array[PackedScene]) -> void:
	_preloaded_scenes.clear()
	for packed_scene in scenes:
		_preloaded_scenes[packed_scene.resource_path] = packed_scene

@rpc("authority", "call_remote", "reliable")
func _spawn(scene_path : String, absolute_node_path : String, data : Dictionary) -> void:
	
	var scene : PackedScene = null
	if _preloaded_scenes.has(scene_path):
		scene = _preloaded_scenes.get(scene_path)
	else:
		scene = load(scene_path) as PackedScene
	
	if not scene:
		_logger.error("Cant load scene from received path: %s" %scene_path)
		return
	
	var spawned_node := scene.instantiate() as Node
	
	if not spawned_node:
		_logger.error("Cant instantiate scene from received path: %s" %scene_path)
		return
		
	var parent_node := get_node(absolute_node_path)
	
	if not parent_node:
		_logger.error("Cant find parent node from received path: %s" %absolute_node_path)
		return
	
	parent_node.add_child(spawned_node, true)
	
	for key in data.keys():
		if key is String:
			spawned_node.set_indexed(key, data[key])
		else:
			_logger.warning("Received non string property name in data dictionary.")
			continue
	
	_logger.info("Instantiated scene %s" %spawned_node.name)

@rpc("authority", "call_remote", "reliable")
func _despawn(absolute_node_path : String) -> void:
	var node := get_node(absolute_node_path)
	if not node:
		_logger.error("Cant fetch node with path %s to despawn" %absolute_node_path)
		return
	
	_logger.info("Erased scene %s" %node.name)
	node.queue_free()
