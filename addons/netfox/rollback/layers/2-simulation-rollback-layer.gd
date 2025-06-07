extends "res://addons/netfox/rollback/layers/1-configurable-rollback-layer.gd"

@export_category("Rollback Synchronizer")

@export var enable_prediction: bool

var _simset: _Set = _Set.new()
var _skipset: _Set = _Set.new()

var _freshness_store := RollbackFreshnessStore.new()

var _latest_state_tick: int
var _earliest_input_tick: int
var _last_simulated_tick: int

var _has_input: bool
var _input_tick: int
var _is_predicted_tick: bool

func _connect_signals() -> void:
	super()
	NetworkRollback.before_loop.connect(_notify_resimulation_start)
	NetworkRollback.on_prepare_tick.connect(_prepare_tick_sim)
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkTime.after_tick_loop.connect(_reset_sim_ticks)

func _disconnect_signals() -> void:
	super()
	NetworkRollback.before_loop.disconnect(_notify_resimulation_start)
	NetworkRollback.on_prepare_tick.disconnect(_prepare_tick_sim)
	NetworkRollback.on_process_tick.disconnect(_process_tick)
	NetworkTime.after_tick_loop.disconnect(_reset_sim_ticks)

func _notify_resimulation_start() -> void:
	if _get_owned_input_props().is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_resimulation_start(_earliest_input_tick)
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_resimulation_start(_latest_state_tick)

func _prepare_tick_sim(tick: int) -> void:
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var retrieved_tick := _inputs.get_closest_tick(tick)
	var state := _states.get_history(tick)
	var input := _inputs.get_history(tick)

	state.apply(_property_cache)
	input.apply(_property_cache)

	# Save data for input prediction
	_has_input = retrieved_tick != -1
	_input_tick = retrieved_tick
	_is_predicted_tick = _is_predicted_tick_for(null, tick)

	# Reset the set of simulated and ignored nodes
	_simset.clear()
	_skipset.clear()

	# Gather nodes that can be simulated
	for node in _nodes:
		if _can_simulate(node, tick):
			NetworkRollback.notify_simulated(node)

func _can_simulate(node: Node, tick: int) -> bool:
	if not enable_prediction and _is_predicted_tick_for(node, tick):
		# Don't simulate if prediction is not allowed and tick is predicted
		return false
	if NetworkRollback.is_mutated(node, tick):
		# Mutated nodes are always resimulated
		return true
	if _input_property_config.is_empty():
		# If we're running inputless and own the node, simulate it if we haven't
		if node.is_multiplayer_authority():
			return tick > _last_simulated_tick
		# If we're running inputless and don't own the node, only run as prediction
		return enable_prediction
	if node.is_multiplayer_authority():
		# Simulate from earliest input
		# Don't simulate frames we don't have input for
		return tick >= _earliest_input_tick
	else:
		# Simulate ONLY if we have state from server
		# Simulate from latest authorative state - anything the server confirmed we don't rerun
		# Don't simulate frames we don't have input for
		return tick >= _latest_state_tick

# `node` can be set to null, in case we're not simulating a specific node
func _is_predicted_tick_for(node: Node, tick: int) -> bool:
	if _input_property_config.is_empty() and node != null:
		# We're running without inputs
		# It's only predicted if we don't own the node
		return not node.is_multiplayer_authority()
	else:
		# We have input properties, it's only predicted if we don't have the input for the tick
		return not _inputs.has(tick)

func _process_tick(tick: int) -> void:
	# Simulate rollback tick
	#	Method call on rewindables
	#	Rollback synchronizers go through each node they manage
	#	If current tick is in node's range, tick
	#		If authority: Latest input >= tick >= Latest state
	#		If not: Latest input >= tick >= Earliest input
	for node in _nodes:
		if not NetworkRollback.is_simulated(node):
			continue

		var is_fresh := _freshness_store.is_fresh(node, tick)
		_is_predicted_tick = _is_predicted_tick_for(node, tick)
		NetworkRollback.process_rollback(node, NetworkTime.ticktime, tick, is_fresh)

		if _skipset.has(node):
			continue

		_freshness_store.notify_processed(node, tick)
		_simset.add(node)

func _reset_sim_ticks() -> void:
	_earliest_input_tick = NetworkTime.tick
	# TODO: Trim freshness store here
