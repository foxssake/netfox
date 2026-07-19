class_name RollbackDisplayRef
extends RefCounted

var _node_ref: WeakRef
var _property: NodePath


func _init(node: Node, property: NodePath) -> void:
	_node_ref = weakref(node)
	_property = property


func is_valid() -> bool:
	return _get_node() != null


func get_value() -> Variant:
	var node: Node = _get_node()
	if node == null:
		return null

	var latest_inputs_complete_tick: int = NetworkSynchronizationServer.get_latest_inputs_complete_tick()
	if latest_inputs_complete_tick < 0:
		return node.get_indexed(_property)

	var target_tick: int = mini(latest_inputs_complete_tick, NetworkRollback.display_tick)
	var resolved_tick: int = NetworkHistoryServer.get_latest_state_tick_for([node], target_tick)
	if resolved_tick < 0:
		return node.get_indexed(_property)

	return NetworkHistoryServer._rb_state_history.get_property(
		resolved_tick,
		node,
		_property,
		node.get_indexed(_property),
	)


func _get_node() -> Node:
	var node: Variant = _node_ref.get_ref()
	if not node is Node:
		return null
	return node
