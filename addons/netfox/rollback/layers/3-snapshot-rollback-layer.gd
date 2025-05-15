extends "res://addons/netfox/rollback/layers/2-simulation-rollback-layer.gd"

func _connect_signals() -> void:
	super()
	NetworkRollback.on_prepare_tick.connect(_prepare_tick)
	NetworkRollback.on_record_tick.connect(_record_tick)
	NetworkTime.after_tick_loop.connect(_apply_display_state)
	NetworkTime.before_tick.connect(_apply_tick_state)
	NetworkTime.after_tick.connect(_trim_history)

func _disconnect_signals() -> void:
	super()
	NetworkRollback.on_prepare_tick.disconnect(_prepare_tick)
	NetworkRollback.on_record_tick.disconnect(_record_tick)
	NetworkTime.after_tick_loop.disconnect(_apply_display_state)
	NetworkTime.before_tick.disconnect(_apply_tick_state)
	NetworkTime.after_tick.disconnect(_trim_history)

func _prepare_tick(tick: int) -> void:
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var retrieved_tick := _inputs.get_closest_tick(tick)
	var state := _states.get_history(tick)
	var input := _inputs.get_history(tick)

	state.apply(_property_cache)
	input.apply(_property_cache)

func _should_record_tick(tick: int) -> bool:
	if _get_recorded_state_props().is_empty():
		# Don't record tick if there's no props to record
		return false

	if _get_recorded_state_props().any(func(pe):
		return NetworkRollback.is_mutated(pe.node, tick - 1)):
		# If there's any node that was mutated, there's something to record
		return true

	# Otherwise, record only if we don't have authoritative state for the tick
	return tick > _latest_state_tick

func _should_record_property(property_entry: PropertyEntry) -> bool:
	if NetworkRollback.is_mutated(property_entry.node):
		return true
	if _skipset.has(property_entry.node):
		return false
	return true

func _get_state_props_to_record(tick: int) -> Array[PropertyEntry]:
	if not _should_record_tick(tick):
		return []
	if _skipset.is_empty():
		return _get_recorded_state_props()

	var result: Array[PropertyEntry] = []
	for property_entry in _get_recorded_state_props():
		if NetworkRollback.is_mutated(property_entry.node, tick - 1):
			result.append(property_entry)
		elif not _skipset.has(property_entry.node):
			result.append(property_entry)
	return _get_recorded_state_props().filter(func(pe): return _should_record_property(pe))

func _record_tick(tick: int):
	# Record state for specified tick ( current + 1 )
	# Check if any of the managed nodes were mutated
	var is_mutated := _get_recorded_state_props().any(func(pe):
		return NetworkRollback.is_mutated(pe.node, tick - 1))

	var record_state := _PropertySnapshot.extract(_get_state_props_to_record(tick))
	if record_state.size():
		var merge_state := _states.get_history(tick - 1)
		_states.set_snapshot(tick, merge_state.merge(record_state))

	# Push metrics
	NetworkPerformance.push_rollback_nodes_simulated(_simset.size())

func _apply_display_state() -> void: # after loop
	# Apply display state
	var display_state := _states.get_history(NetworkRollback.display_tick)
	display_state.apply(_property_cache)

func _apply_tick_state(_delta: float, tick: int) -> void: # before tick
	# Apply state for tick
	var state = _states.get_history(tick)
	state.apply(_property_cache)

func _trim_history(_delta: float, _tick: int) -> void: # after tick
	# Trim history
	_states.trim()
	_inputs.trim()
	_freshness_store.trim()
