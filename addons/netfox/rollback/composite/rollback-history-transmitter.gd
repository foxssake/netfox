extends Node # TODO: Not node
class_name RollbackHistoryTransmitter

var root: Node
var enable_input_broadcast: bool = true
var full_state_interval: int
var diff_ack_interval: int

# Provided externally by RBS
var _state_history: _PropertyHistoryBuffer
var _input_history: _PropertyHistoryBuffer
var _freshness_store: RollbackFreshnessStore

var _state_property_config: _PropertyConfig
var _input_property_config: _PropertyConfig

var _property_cache: PropertyCache

# Collaborators
var _input_encoder := _RedundantHistoryEncoder.new(_input_history, _property_cache)
var _full_state_encoder := _SnapshotHistoryEncoder.new(_state_history, _property_cache)
var _diff_state_encoder := _DiffHistoryEncoder.new(_state_history, _property_cache)

# State
var _ackd_state: Dictionary = {}
var _next_full_state_tick: int
var _next_diff_ack_tick: int

# Signals
signal _on_transmit_state(state: Dictionary, tick: int)

# idk?
var _is_predicted_tick: bool
var _skipset: _Set
var _earliest_input_tick: int # Expose as state?
var _latest_state_tick: int # Expose as state?
var _is_initialized: bool

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("RollbackHistoryTransmitter")

func _connect_signals() -> void:
	NetworkTime.after_tick.connect(_transmit_input)
	NetworkRollback.on_record_tick.connect(_broadcast_tick)

func _disconnect_signals() -> void:
	NetworkTime.after_tick.disconnect(_transmit_input)
	NetworkRollback.on_record_tick.disconnect(_broadcast_tick)

func _transmit_input(_dt: float, tick: int) -> void:
	# Transmit input
	if not _get_owned_input_props().is_empty():
		var input_tick: int = tick + NetworkRollback.input_delay
		var input_data := _input_encoder.encode(input_tick, _get_owned_input_props())
		var target_peer := 0 if enable_input_broadcast else root.get_multiplayer_authority()
		if target_peer != multiplayer.get_unique_id():
			_submit_input.rpc_id(target_peer, input_tick, input_data)

func _broadcast_tick(tick: int):
	if _get_owned_state_props().is_empty() or _is_predicted_tick:
		return

	# Include properties we own
	var full_state := _PropertySnapshot.new()

	for property in _get_owned_state_props():
		if _should_broadcast(property, tick):
			full_state.set_value(property.to_string(), property.get_value())

	_on_transmit_state.emit(full_state, tick)

	# No properties to send?
	if full_state.is_empty():
		return

	# _latest_state_tick = max(_latest_state_tick, tick) # TODO: Simulator
	_state_history.merge(full_state, tick)

	var is_sending_diffs := NetworkRollback.enable_diff_states
	var is_full_state_tick := not is_sending_diffs or (full_state_interval > 0 and tick > _next_full_state_tick)

	if is_full_state_tick:
		# Broadcast new full state
		_send_full_state(tick)

		# Adjust next full state if sending diffs
		if is_sending_diffs:
			_next_full_state_tick = tick + full_state_interval
	else:
		# Send diffs to each peer
		for peer in multiplayer.get_peers():
			var reference_tick := _ackd_state.get(peer, -1) as int
			if reference_tick < 0 or not _state_history.has(reference_tick):
				# Peer hasn't ack'd any tick, or we don't have the ack'd tick
				# Send full state
				_send_full_state(tick, peer)
				continue

			# Prepare diff
			var diff_state_data := _diff_state_encoder.encode(tick, reference_tick, _get_owned_state_props())
			if diff_state_data.size() == full_state.size():
				# State is completely different, send full state
				_send_full_state(tick, peer)
			else:
				# Send only diff
				_submit_diff_state.rpc_id(peer, diff_state_data, tick, reference_tick)

				# Push metrics
				NetworkPerformance.push_full_state(_diff_state_encoder.get_full_snapshot())
				NetworkPerformance.push_sent_state(_diff_state_encoder.get_encoded_snapshot())

func _should_broadcast(property: PropertyEntry, tick: int) -> bool:
	# Only broadcast if we've simulated the node
	# NOTE: _can_simulate checks mutations, but to override _skipset
	# we check first
	if NetworkRollback.is_mutated(property.node, tick - 1):
		return true
	if _skipset.has(property.node):
		return false
	if _is_predicted_tick_for(property.node, tick - 1):
		return false
	return _can_simulate(property.node, tick - 1)

func _send_full_state(tick: int, peer: int = 0) -> void:
	var full_state_snapshot := _state_history.get_snapshot(tick).as_dictionary()
	var full_state_data := _full_state_encoder.encode(tick, _get_owned_state_props())

	if peer == 0:
		_submit_full_state.rpc(full_state_data, tick)

		NetworkPerformance.push_full_state_broadcast(full_state_snapshot)
		NetworkPerformance.push_sent_state_broadcast(full_state_snapshot)
	else:
		_submit_full_state.rpc_id(peer, full_state_data, tick)

		NetworkPerformance.push_full_state(full_state_snapshot)
		NetworkPerformance.push_sent_state(full_state_snapshot)


@rpc("any_peer", "unreliable", "call_remote")
func _submit_input(tick: int, data: Array) -> void:

	var sender := multiplayer.get_remote_sender_id()
	var snapshots := _input_encoder.decode(data, _input_property_config.get_properties_owned_by(sender))
	var earliest_received_input = _input_encoder.apply(tick, snapshots, sender)
	if earliest_received_input >= 0:
		_earliest_input_tick = mini(_earliest_input_tick, earliest_received_input)

# `serialized_state` is a serialized _PropertySnapshot
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_full_state(data: Array, tick: int) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var sender := multiplayer.get_remote_sender_id()
	var snapshot := _full_state_encoder.decode(data, _state_property_config.get_properties_owned_by(sender))
	if _full_state_encoder.apply(tick, snapshot, sender):
		_latest_state_tick = tick

# State is a serialized _PropertySnapshot (Dictionary[String, Variant])
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_diff_state(data: PackedByteArray, tick: int, reference_tick: int) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var sender = multiplayer.get_remote_sender_id()
	var diff_snapshot := _diff_state_encoder.decode(data, _state_property_config.get_properties_owned_by(sender))
	if not _diff_state_encoder.apply(tick, diff_snapshot, reference_tick, sender):
		# Invalid data
		return

	_latest_state_tick = tick

	if NetworkRollback.enable_diff_state_history:
		if diff_ack_interval > 0 and tick > _next_diff_ack_tick:
			_ack_diff_state.rpc_id(sender, tick)
			_next_diff_ack_tick = tick + diff_ack_interval

@rpc("any_peer", "reliable", "call_remote")
func _ack_full_state(tick: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd full state for tick %d", [sender_id, tick])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _ack_diff_state(tick: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd diff state for tick %d", [sender_id, tick])

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

# =============================================================================
# idk?
func _is_predicted_tick_for(node: Node, tick: int) -> bool:
	return false

func _can_simulate(node: Node, tick: int) -> bool:
	return false
