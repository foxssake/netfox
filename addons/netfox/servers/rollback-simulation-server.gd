extends Node
class_name _RollbackSimulationServer

# node to callback
# TODO: Consider allowing any Object, not just nodes
var _callbacks := {}
# node to input node
# TODO: Support multiple input nodes for a single simulated node
var _input_for := {}

var _predicted_nodes := [] as Array[Node]

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
	deregister_input(node)

func register_input_for(node: Node, input: Node) -> void:
	_input_for[node] = input

func deregister_input(node: Node) -> void:
	_input_for.erase(node)

func get_nodes_to_simulate(snapshot: Snapshot) -> Array[Node]:
	var result: Array[Node] = []
	if not snapshot:
		return []

	for node in _callbacks.keys():
		if not _input_for.has(node):
			# Node has no input, simulate it
			result.append(node)
			continue

		var input := _input_for[node] as Node
		if not snapshot.has_node(input, true):
			continue

		result.append(node)

	return result

func is_predicting(snapshot: Snapshot, node: Node) -> bool:
	if not node.is_multiplayer_authority():
		# We don't own the node, so we can only guess - i.e. predict
		return true
	if not _input_for.has(node):
		# We own the node, node doesn't depend on input, we're sure
		return false
	if not snapshot.has_node(_input_for[node], true):
		# We own the node, node depends on input, we don't have data for input - predict
		return true
	# We own the node and we have data for node's input - we're sure
	return false

func simulate(delta: float, tick: int) -> void:
	var snapshot := RollbackHistoryServer.get_snapshot(tick)
	var nodes := get_nodes_to_simulate(snapshot)
	_predicted_nodes.clear()
	_logger.debug("Simulating %d nodes: %s", [nodes.size(), nodes])

	# Sort based on SceneTree order
	for node in nodes:
		node.add_to_group(_group)
	nodes = get_tree().get_nodes_in_group(_group)

	# Run callbacks and clear group
	for node in nodes:
		var callback := _callbacks[node] as Callable
		callback.call(delta, tick, false) # TODO: is_fresh
		node.remove_from_group(_group)
		
		if is_predicting(snapshot, node):
			_predicted_nodes.append(node)

	# Metrics
	NetworkPerformance.push_rollback_nodes_simulated(nodes.size())

func get_predicted_nodes() -> Array[Node]:
	return _predicted_nodes
