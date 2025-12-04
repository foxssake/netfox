extends Node
class_name _RollbackSimulationServer

# node to callback
# TODO: Consider allowing any Object, not just nodes
var _callbacks := {}

var _group := StringName("__nf_rollback_sim" + str(get_instance_id()))

static var _logger := NetfoxLogger._for_netfox("RollbackSimulationServer")

func register(callback: Callable) -> void:
	if not is_instance_valid(callback.get_object()):
		_logger.error("Trying to register callback that belongs to an invalid object!")
		return

	_callbacks[callback.get_object()] = callback

func deregister(callback: Callable) -> void:
	if not is_instance_valid(callback.get_object()):
		return

	if _callbacks[callback.get_object()] != callback:
		return

	_callbacks.erase(callback.get_object())

func deregister_node(node: Node) -> void:
	_callbacks.erase(node)

func get_nodes_to_simulate() -> Array[Node]:
	var result: Array[Node] = []
	result.assign(_callbacks.keys())
	return result

func simulate(delta: float, tick: int) -> void:
	var nodes := get_nodes_to_simulate()

	# Sort based on SceneTree order
	for node in nodes:
		node.add_to_group(_group)
	nodes = get_tree().get_nodes_in_group(_group)

	# Run callbacks and clear group
	for node in nodes:
		var callback := _callbacks[node] as Callable
		callback.call(delta, tick, false) # TODO: is_fresh
		node.remove_from_group(_group)

	# Metrics
	NetworkPerformance.push_rollback_nodes_simulated(nodes.size())
