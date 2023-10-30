extends RefCounted
class_name PropertyCache

var root: Node
var _cache: Dictionary = {}

func _init(p_root: Node):
	root = p_root

func get_entry(path: String) -> PropertyEntry:
	if not _cache.has(path):
		var parsed = PropertyEntry.parse(root, path)
		if not parsed.is_valid():
			push_warning("Invalid property path: %s" % path)
		_cache[path] = parsed
	return _cache[path]

func properties() -> Array:
	var result: Array[PropertyEntry]
	# Can be slow, but no other way to do this with type-safety
	# See: https://github.com/godotengine/godot/issues/72627
	result.assign(_cache.values())
	return result
