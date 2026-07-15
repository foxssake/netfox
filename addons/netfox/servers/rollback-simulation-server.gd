extends Node
class_name _RollbackSimulationServer

# @public class

## Runs gameplay simulation during rollback
##
## Rollback involves restoring the game state to an earlier point in time and
## re-running game logic from there. This class tracks which nodes participate
## in rollback, which of them need to be actually simulated, and runs the
## simulation itself.
## [br][br]
## Node simulation honors scene tree order. Processing order and physics
## processing order are [b]not[/b] considered.
## [br][br]
## To participate in rollback, call [method register] using the method to call
## to simulate the node. Only one [Callable] can be actively registered per
## node.

var _history_server: _NetworkHistoryServer
var _liveness_server: _RollbackLivenessServer

var _callbacks := {}		# node to callback
var _simulated_ticks := {}	# node to array of ticks
var _prediction_enabled_nodes := _Set.new()

var _input_graph := _Graph.new() # Links inputs to objects controlled by them

# Currently simulated object
var _current_object: Object = null
# Predicted nodes for next simulation
var _predicted_subjects := _Set.new()

var _group := StringName("__nf_rollback_sim" + str(get_instance_id()))
var _objects := [] as Array[Object]

static var _logger := NetfoxLogger._for_netfox("RollbackSimulationServer")

## Register a [param callback] to run as part of the rollback loop
func register(callback: Callable) -> void:
	if not is_instance_valid(callback.get_object()):
		_logger.error("Trying to register callback that belongs to an invalid object!")
		return

	var subject := callback.get_object()
	assert(subject, "Only nodes supported for now!")
	assert(not _callbacks.has(subject), "Double register() of node %s!" % [subject])
	assert((subject as Node).is_inside_tree(), "Node %s is not inside the tree!" % [subject])

	_callbacks[subject] = callback
	if subject is Node:
		subject.add_to_group(_group)
	else:
		_objects.append(subject)

## Deregister a [param callback] from the rollback loop
func deregister(callback: Callable) -> void:
	if not callback or not callback.is_valid(): return

	var subject := callback.get_object()

	if not is_instance_valid(subject): return
	if _callbacks[subject] != callback: return

	_callbacks.erase(subject)
	_input_graph.erase(subject)
	_simulated_ticks.erase(subject)
	
	if subject is Node:
		subject.remove_from_group(_group)
	else:
		_objects.erase(subject)

## Deregister a [param node] from the rollback loop
func deregister_node(node: Node) -> void:
	if _callbacks.has(node):
		deregister(_callbacks[node])
	_input_graph.erase(node)
	_prediction_enabled_nodes.erase(node)
	# TODO: Reconsider the above, we currently only support one callback per subject

## Register [param input] as providing input for [param node]
func register_rollback_input_for(subject: Object, input: Object) -> void:
	_input_graph.link(input, subject)

## Deregister [param input] from providing input for [param node]
func deregister_rollback_input(subject: Object, input: Object) -> void:
	_input_graph.unlink(input, subject)

## Toggle the prediction enabled flag for [param node]
## [br][br]
## Prediction in this sense means that the node will be simulated even if there
## is no up to date input available.
func set_prediction_enabled_for(subject: Object, enabled: bool) -> void:
	if enabled:
		_prediction_enabled_nodes.add(subject)
	else:
		_prediction_enabled_nodes.erase(subject)

## Return true if prediction is enabled for [param node]
## [br][br]
## Prediction in this sense means that the node will be simulated even if there
## is no up to date input available.
func is_prediction_enabled_for(subject: Object) -> bool:
	return _prediction_enabled_nodes.has(subject)

## Return true if the currently simulated node is being predicted
func is_predicting_current() -> bool:
	if not _current_object or not is_instance_valid(_current_object):
		return false
	return _predicted_subjects.has(_current_object)

## Get the currently simulated object
func get_simulated_object() -> Object:
	return _current_object

## Simulate a tick
func simulate(delta: float, tick: int) -> void:
	_current_object = null

	var input_snapshot := NetworkHistoryServer._get_rollback_input_snapshot(tick)
	var state_snapshot := NetworkHistoryServer._get_rollback_state_snapshot(tick)
	var subjects := _get_subjects_to_simulate(input_snapshot) # Result is sorted by tree order
	_predicted_subjects.clear()

	# Determine predicted subjects
	for subject in _callbacks.keys():
		if _is_predicting(input_snapshot, subject):
			_predicted_subjects.add(subject)

	# Run callbacks and clear group
	for subject in subjects:
		_current_object = subject

		var callback := _callbacks[subject] as Callable
		var is_fresh := _is_tick_fresh_for(subject, tick)
		callback.call(delta, tick, is_fresh)

		_current_object = null
		_set_tick_simulated_for(subject, tick)

	# Metrics
	NetworkPerformance.push_rollback_nodes_simulated(subjects.size())

# Returns nodes in scene tree order
func _get_subjects_to_simulate(input_snapshot: _Snapshot) -> Array[Node]:
	var result: Array[Node] = []
	if not input_snapshot:
		return []

	var tick := input_snapshot.tick
	for subject in get_tree().get_nodes_in_group(_group) + _objects:
		if not _liveness_server.is_alive(subject, tick):
			# Node is not alive in this tick
			continue

		var inputs := [] as Array[Object]
		inputs.assign(_input_graph.get_linked_to(subject))

		if inputs.is_empty():
			# Node has no input, simulate it
			result.append(subject)
			continue

		if NetworkRollback.is_mutated(subject, tick):
			# Node is mutated, must simulate
			result.append(subject)
			continue

		if not input_snapshot.has_subjects(inputs, true) and \
			not is_prediction_enabled_for(subject):
			# We don't have input for node, and input prediction is disabled
			# Don't simulate
			continue

		result.append(subject)

	return result

func _is_predicting(input_snapshot: _Snapshot, subject: Object) -> bool:
	var input_nodes := [] as Array[Object]
	input_nodes.assign(_input_graph.get_linked_to(subject))

	var is_owned := NetworkObjectServer.is_authority_of(subject)
	var is_inputless := input_nodes.is_empty()
	var has_input := false

	if not is_inputless and input_snapshot:
		has_input = input_snapshot.has_subjects(input_nodes, true)

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

func _is_tick_fresh_for(subject: Object, tick: int) -> bool:
	if not _simulated_ticks.has(subject):
		return true
	var ticks := _simulated_ticks.get(subject) as Array[int]
	return not ticks.has(tick)

func _set_tick_simulated_for(subject: Object, tick: int) -> void:
	if not _simulated_ticks.has(subject):
		_simulated_ticks[subject] = [tick] as Array[int]
	else:
		_simulated_ticks[subject].append(tick)

func _trim_ticks_simulated(beginning: int) -> void:
	for object in _simulated_ticks:
		_simulated_ticks[object] = _simulated_ticks[object]\
			.filter(func(tick): return tick >= beginning)

func _get_controlled_by(input: Object) -> Array[Object]:
	var result := [] as Array[Object]
	result.assign(_input_graph.get_linked_from(input))
	return result

func _get_inputs_of(subject: Object) -> Array[Object]:
	var result := [] as Array[Object]
	result.assign(_input_graph.get_linked_to(subject))
	return result

func _init(p_history_server: _NetworkHistoryServer = null, p_liveness_server: _RollbackLivenessServer = null):
	_history_server = p_history_server
	_liveness_server = p_liveness_server

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _liveness_server: _liveness_server = RollbackLivenessServer
	# TODO: Consider NetworkObjectServer as dependency
