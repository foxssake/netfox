extends Object
class_name _NetfoxEditorUtils

static func gather_properties(root: Node, callback_name: String, handler: Callable) -> Array[String]:
	var result: Array[String] = []

	var nodes: Array[Node] = root.find_children("*")
	nodes.push_back(root)
	for node in nodes:
		if not node.has_method(callback_name):
			continue

		var readable_node_name := "\"%s\" (\"%s\")" % [node.name, root.get_path_to(node)]
		if node.get(callback_name) == null:
			result.push_back("Can't grab method \"%s\" from node %s! Is it a @tool?" % [callback_name, readable_node_name])
			continue

		var props = node.get(callback_name).call()
		if not props is Array:
			result.push_back("Node %s didn't return an array on calling \"%s\"" % [readable_node_name, callback_name])
			continue

		for prop in props:
			handler.call(node, prop)

	return result
