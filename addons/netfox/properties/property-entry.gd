extends RefCounted
class_name PropertyEntry

var _path: String
var node: Node
var property: String

static var _logger := NetfoxLogger._for_netfox("PropertyEntry")

func get_value() -> Variant:
	return node.get_indexed(property)

func set_value(value):
	node.set_indexed(property, value)

func is_valid() -> bool:
	if not node or not is_instance_valid(node):
		# Node is invalid
		return false

	# Return true if node has given property
	return node.get_property_list()\
		.any(func(it): return it["name"] == property)

func _to_string() -> String:
	return _path

static func parse(root: Node, path: String) -> PropertyEntry:
	var result = PropertyEntry.new()
	result.node = root.get_node(NodePath(path))
	result.property = path.erase(0, path.find(":") + 1)
	result._path = path
	return result

static func make_path(root: Node, node: Variant, property: String) -> String:
	var node_path := ""

	if node is String:
		node_path = node
	elif node is NodePath:
		node_path = str(node)
	elif node is Node:
		node_path = str(root.get_path_to(node))
	else:
		_logger.error("Can't stringify node reference: %s", [node])
		return ""

	if node_path == ".":
		node_path = ""

	return "%s:%s" % [node_path, property]
