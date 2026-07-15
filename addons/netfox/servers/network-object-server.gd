extends Node
class_name _NetworkObjectServer

# @public class

var resource_load_mode := ResourceLoadMode.ALLOW_LIST

var _registered_objects := {} # string to object
var _object_paths := {} # object to string, reverse of `_registered_objects`

var _allowed_resource_paths := _Set.new()
var _disallowed_resource_paths := _Set.new()

var _authorities := {} # object to peer id

enum ResourceLoadMode {
	NONE,
	ALLOW_LIST,
	DENY_LIST,
	ANY
}

func allow_resource(path: String) -> void:
	_allowed_resource_paths.add(path)
	_disallowed_resource_paths.erase(path)

func disallow_resource(path: String) -> void:
	_allowed_resource_paths.erase(path)
	_disallowed_resource_paths.add(path)

func register(path: String, object: Object) -> void:
	_registered_objects[path] = object
	_object_paths[object] = path

func deregister(object: Object) -> void:
	if has(object):
		var path := get_path_of(object)
		_registered_objects.erase(path)
		_object_paths.erase(object)

func has(object: Object) -> bool:
	return _registered_objects.has(object)

func get_path_of(object: Object) -> String:
	if object is Node:
		if object.is_inside_tree():
			# Node only has path if it's in tree
			# NOTE: Use `get_path_to(object)` when going for branch support
			return object.get_path()
	
	if object is Resource:
		return object.resource_path
		
	if _object_paths.has(object):
		return _object_paths.get(object)
	
	return ""

func resolve_path(path: String) -> Object:
	# Check if it's a node
	# NOTE: Eventually we might want to support different instances running on
	# different scene tree branches
	var node := get_node_or_null(path)
	if node != null:
		return node

	# Check if it's a resource
	var resource := _try_fetch_resource(path)
	if resource != null:
		return resource

	# Maybe it was manually registered
	if _registered_objects.has(path):
		return _registered_objects.get(path)

	# No idea
	return null

func get_authority_of(object: Object) -> int:
	if object is Node:
		return object.get_multiplayer_authority()
	
	return _authorities.get(object, 1)

func set_authority_of(object: Object, authority: int, recursive: bool = true) -> void:
	if object is Node:
		object.set_multiplayer_authority(authority, recursive)
	else:
		_authorities[object] = authority

func is_authority_of(object: Object, peer: int = multiplayer.get_unique_id()) -> bool:
	return get_authority_of(object) == peer

func queue_free_object(object: Object) -> void:
	deregister(object)
	
	if object is Node:
		object.queue_free()
	elif object is Resource:
		# TODO: Does it make sense to free a Resource?
		object.free()
	else:
		object.free()

func _try_fetch_resource(path: String) -> Resource:
	match resource_load_mode:
		# No resource loading is allowed, always return `null`
		ResourceLoadMode.NONE:
			return null
			
		# Only load explicitly allowed resources
		ResourceLoadMode.ALLOW_LIST:
			if _allowed_resource_paths.has(path):
				return load(path)
				
		# Load resource only if it's not disallowed
		ResourceLoadMode.DENY_LIST:
			if not _disallowed_resource_paths.has(path):
				return load(path)
				
		# Load any resource
		ResourceLoadMode.ANY:
			return load(path)
			
	return null
