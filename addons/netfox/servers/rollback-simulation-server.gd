extends Node
class_name _RollbackSimulationServer

# node to callback
# TODO: Consider allowing any Object, not just nodes
var _callbacks := {}
# node to input node
# TODO: Support multiple input nodes for a single simulated node
var _input_for := {}
# node to array of ticks
# used for is_fresh
# TODO: Refactor to ringbuffer containing sets of nodes?
var _simulated_ticks := {}

# Currently simulated object
var _current_object: Object = null
# Predicted nodes for next simulation
# TODO: _Set?
var _predicted_nodes := [] as Array[Node]

var _group := StringName("__nf_rollback_sim" + str(get_instance_id()))

static var _logger := NetfoxLogger._for_netfox("RollbackSimulationServer")

func register(callback: Callable) -> void:
	if not is_instance_valid(callback.get_object()):
		_logger.error("Trying to register callback that belongs to an invalid object!")
		return

	_callbacks[callback.get_object()] = callback

func deregister(callback: Callable) -> void:
	if not callback or not callback.is_valid(): return

	var object := callback.get_object()

	if not is_instance_valid(object): return
	if _callbacks[object] != callback: return

	_callbacks.erase(object)
	_input_for.erase(object)
	_simulated_ticks.erase(object)

func deregister_node(node: Node) -> void:
	deregister(_callbacks.get(node))

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
			# We don't have input for node, don't simulate
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

func is_predicting_current() -> bool:
	if not _current_object or not is_instance_valid(_current_object):
		return false
	return _predicted_nodes.has(_current_object)

func is_tick_fresh_for(node: Node, tick: int) -> bool:
	if not _simulated_ticks.has(node):
		return false
	var ticks := _simulated_ticks.get(node) as Array[int]
	return ticks.has(tick)

func set_tick_simulated_for(node: Node, tick: int) -> void:
	if not _simulated_ticks.has(node):
		_simulated_ticks[node] = [tick] as Array[int]
	else:
		_simulated_ticks[node].append(tick)

func trim_ticks_simulated(beginning: int) -> void:
	for object in _simulated_ticks:
		_simulated_ticks[object] = _simulated_ticks[object]\
			.filter(func(tick): return tick >= beginning)

func simulate(delta: float, tick: int) -> void:
	_current_object = null

	var snapshot := RollbackHistoryServer.get_snapshot(tick)
	var nodes := get_nodes_to_simulate(snapshot)
	_predicted_nodes.clear()
	_logger.debug("Simulating %d nodes: %s", [nodes.size(), nodes])

	# Sort based on SceneTree order
	for node in nodes:
		node.add_to_group(_group)
	nodes = get_tree().get_nodes_in_group(_group)

	# Determine predicted nodes
	for node in _callbacks.keys():
		if is_predicting(snapshot, node):
			_predicted_nodes.append(node)

	# Run callbacks and clear group
	for node in nodes:
		_current_object = node

		var callback := _callbacks[node] as Callable
		var is_fresh := is_tick_fresh_for(node, tick)
		callback.call(delta, tick, is_fresh)
		node.remove_from_group(_group)

		_current_object = null
		set_tick_simulated_for(node, tick)

	# Metrics
	NetworkPerformance.push_rollback_nodes_simulated(nodes.size())

func get_predicted_nodes() -> Array[Node]:
	return _predicted_nodes
