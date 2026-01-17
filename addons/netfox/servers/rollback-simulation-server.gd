extends Node
class_name _RollbackSimulationServer

# node to callback
# TODO: Consider allowing any Object, not just nodes
var _callbacks := {}
# node to array of ticks
# used for is_fresh
# TODO: Refactor to ringbuffer containing sets of nodes?
var _simulated_ticks := {}

var _input_graph := _Graph.new() # Links inputs to objects controlled by them

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
	_input_graph.erase(object)
	_simulated_ticks.erase(object)

func deregister_node(node: Node) -> void:
	deregister(_callbacks.get(node))

func register_input_for(node: Node, input: Node) -> void:
	_input_graph.link(input, node)

func deregister_input(node: Node, input: Node) -> void:
	_input_graph.unlink(input, node)

func get_nodes_to_simulate(input_snapshot: Snapshot) -> Array[Node]:
	var result: Array[Node] = []
	if not input_snapshot:
		return []

	for node in _callbacks.keys():
		var inputs := [] as Array[Node]
		inputs.assign(_input_graph.get_linked_to(node))

		if inputs.is_empty():
			# Node has no input, simulate it
			result.append(node)
			continue

		if not input_snapshot.has_nodes(inputs, true):
			# We don't have input for node, don't simulate
			continue

		result.append(node)

	return result

# TODO: *Thorough* test for node predict rules
func is_predicting(input_snapshot: Snapshot, node: Node) -> bool:
	var input_nodes := [] as Array[Node]
	input_nodes.assign(_input_graph.get_linked_to(node))

	var is_owned := node.is_multiplayer_authority()
	var is_inputless := input_nodes.is_empty()
	var has_input := false if is_inputless else true

	# TODO: Avoid supporting null snapshots if possible
	if not is_inputless and input_snapshot:
		has_input = input_snapshot.has_nodes(input_nodes, true)

	if not is_owned and has_input:
		# We don't own the node, but we own input for it - not (input) predicting
		return false
	if not is_owned:
		# We don't own the node, so we can only guess - i.e. predict
		return true
	if is_owned and is_inputless:
		# We own the node, node doesn't depend on input, we're sure
		return false
	if is_owned and not has_input:
		# We own the node, node depends on input, we don't have data for input - predict
		return true
	# We own the node and we have data for node's input - we're sure
	return false

func is_predicting_current() -> bool:
	if not _current_object or not is_instance_valid(_current_object):
		return false
	return _predicted_nodes.has(_current_object)

func get_simulated_object() -> Object:
	return _current_object

func is_tick_fresh_for(node: Node, tick: int) -> bool:
	if not _simulated_ticks.has(node):
		return true
	var ticks := _simulated_ticks.get(node) as Array[int]
	return not ticks.has(tick)

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

	var input_snapshot := RollbackHistoryServer.get_rollback_input_snapshot(tick)
	var state_snapshot := RollbackHistoryServer.get_rollback_state_snapshot(tick)
	var nodes := get_nodes_to_simulate(input_snapshot)
	_predicted_nodes.clear()
	_logger.trace("Simulating %d nodes: %s", [nodes.size(), nodes])

	# Sort based on SceneTree order
	for node in nodes:
		node.add_to_group(_group)
	nodes = get_tree().get_nodes_in_group(_group)

	# Determine predicted nodes
	for node in _callbacks.keys():
		if is_predicting(input_snapshot, node):
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

func get_controlled_by(input: Node) -> Array[Node]:
	var result := [] as Array[Node]
	result.assign(_input_graph.get_linked_from(input))
	return result
