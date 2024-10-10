extends RefCounted
class_name PropertyEntry

var _path: String
var node: Node
var property: String

func get_value() -> Variant:
	return node.get_indexed(property)

func set_value(value):
	node.set_indexed(property, value)

func is_valid() -> bool:
	if node == null:
		return false
		
	if get_value() == null:
		return false
	
	return true

func _to_string() -> String:
	return _path

static func parse(root: Node, path: String) -> PropertyEntry:
	var result = PropertyEntry.new()
	result.node = root.get_node(NodePath(path))
	result.property = path.erase(0, path.find(":") + 1)
	result._path = path
	return result
