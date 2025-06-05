extends RefCounted
class_name RollbackHistoryManager

# Provided externally by RBS
var _state_history: _PropertyHistoryBuffer
var _input_history: _PropertyHistoryBuffer
var _freshness_store: RollbackFreshnessStore

var _state_property_config: _PropertyConfig
var _input_property_config: _PropertyConfig

var _property_cache: PropertyCache

# idk?
var _skipset: _Set
var _latest_state_tick: int

func _connect_signals() -> void:
	NetworkTime.before_tick.connect(_apply_tick_state) # History
	NetworkTime.after_tick.connect(_record_input) # History
	NetworkTime.after_tick.connect(_trim_history) # History
	NetworkRollback.on_prepare_tick.connect(_restore_rollback_tick) # History
	NetworkRollback.on_record_tick.connect(_record_tick) # History
	NetworkRollback.after_loop.connect(_apply_display_state) # History

func _disconnect_signals() -> void:
	NetworkTime.before_tick.disconnect(_apply_tick_state)
	NetworkTime.after_tick.disconnect(_record_input)
	NetworkTime.after_tick.disconnect(_trim_history)
	NetworkRollback.on_prepare_tick.disconnect(_restore_rollback_tick)
	NetworkRollback.on_record_tick.disconnect(_record_tick)
	NetworkRollback.after_loop.disconnect(_apply_display_state)

func _apply_tick_state(_delta: float, tick: int) -> void:
	# Apply state for tick
	var state = _state_history.get_history(tick)
	state.apply(_property_cache)

func _record_input(_dt: float, tick: int) -> void:
	# Record input
	if not _get_recorded_input_props().is_empty():
		var input = _PropertySnapshot.extract(_get_recorded_input_props())
		var input_tick: int = tick + NetworkRollback.input_delay
		_input_history.set_snapshot(input_tick, input)

func _trim_history(_dt: float, _t: int) -> void:
	# Trim history
	_state_history.trim()
	_input_history.trim()
	_freshness_store.trim()

func _restore_rollback_tick(tick: int) -> void:
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var state := _state_history.get_history(tick)
	var input := _input_history.get_history(tick)

	state.apply(_property_cache)
	input.apply(_property_cache)

func _apply_display_state() -> void:
	# Apply display state
	var display_state := _state_history.get_history(NetworkRollback.display_tick)
	display_state.apply(_property_cache)

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

func _record_tick(tick: int):
	# Record state for specified tick ( current + 1 )

	# Check if any of the managed nodes were mutated
	var is_mutated := _get_recorded_state_props().any(func(pe):
		return NetworkRollback.is_mutated(pe.node, tick - 1))

	var record_state := _PropertySnapshot.extract(_get_state_props_to_record(tick))
	if record_state.size():
		var merge_state := _state_history.get_history(tick - 1)
		_state_history.set_snapshot(tick, merge_state.merge(record_state))

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

# =============================================================================
# Shared utils, extract later

func _get_recorded_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_properties()

func _get_owned_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_owned_properties()

func _get_recorded_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()

func _get_owned_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()

