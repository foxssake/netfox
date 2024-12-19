extends Object
class_name _NetfoxEditorUtils

static func gather_properties(root: Node, callback_name: String, handler: Callable) -> Array[String]:
	var result: Array[String] = []

	var nodes: Array[Node] = root.find_children("*")
	nodes.push_front(root)
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
			if prop is String:
				# Property is a string, meaning property path relative to node
				handler.call(node, prop)
			elif prop is Array and prop.size() >= 2:
				# Property is a node-property tuple
				var prop_node: Node = null

				# Node can be a String, NodePath, or an actual Node
				if prop[0] is String or prop[0] is NodePath:
					prop_node = node.get_node(prop[0])
				elif prop[0] is Node:
					prop_node = prop[0]
				else:
					result.push_back("Node %s specified invalid node in \"%s\": %s" % [readable_node_name, callback_name, prop])
					continue

				handler.call(prop_node, prop[1])
			else:
				result.push_back("Node %s specified invalid property in \"%s\": %s" % [readable_node_name, callback_name, prop])

	return result
