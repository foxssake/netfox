extends RefCounted

var enable_prediction: bool = false

func should_simulate(node: Node, tick: int) -> bool:
	if not enable_prediction and _is_predicted_tick_for(node, tick):
		# Don't simulate if prediction is not allowed and tick is predicted
		return false
	if NetworkRollback.is_mutated(node, tick):
		# Mutated nodes are always resimulated
		return true
	if input_properties.is_empty():
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

func should_broadcast(node: Node, tick: int) -> bool:
	return should_simulate(node, tick - 1) \
			and not _skipset.has(node) \
			and not _is_predicted_tick_for(node, tick - 1) \
			or NetworkRollback.is_mutated(node, tick - 1)

func should_record(what: Node) -> bool:
	return false

# `node` can be set to null, in case we're not simulating a specific node
func _is_predicted_tick_for(node: Node, tick: int) -> bool:
	if input_properties.is_empty() and node != null:
		# We're running without inputs
		# It's only predicted if we don't own the node
		return not node.is_multiplayer_authority()
	else:
		# We have input properties, it's only predicted if we don't have the input for the tick
		return not _inputs.has(tick)
