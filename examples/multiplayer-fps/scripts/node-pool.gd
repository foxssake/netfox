extends Node
class_name NodePool

## The maximum objects in the pool
@export var pool_limit: int = 10
## The node to duplicate
@export var target_node: Node: set = _set_target_node
## The flag number to duplicate with
@export var duplicate_flag: int = 15
## Where to spawn additional nodes
@export var spawn_root: Node

var pool: Array[Node] = []

func _set_target_node(new_node: Node) -> void:
	target_node = new_node
	clear()
	_add_node_to_tree(target_node)
	pool = [target_node]
	
func _add_node_to_tree(node: Node) -> void:
	if !node.is_inside_tree():
		if is_instance_valid(spawn_root):
			spawn_root.add_child.call_deferred(node)
		else:
			add_child(node)
			
func next() -> Node:
	var node: Node = pool.pop_front() if pool.size() >= pool_limit else pool[0].duplicate(duplicate_flag)
	pool.append(node)
	_add_node_to_tree(node)
	return node

func clear():
	for node in pool:
		if node.is_instance_valid():
			node.queue_free()
	pool = []
