extends Node
class_name _RollbackHistoryTransmitter

var root: Node
var enable_input_broadcast: bool = true
var full_state_interval: int
var diff_ack_interval: int

# Provided externally by RBS
var _state_history: _PropertyHistoryBuffer
var _input_history: _PropertyHistoryBuffer
var _visibility_filter: PeerVisibilityFilter

var _state_property_config: _PropertyConfig
var _input_property_config: _PropertyConfig

var _property_cache: PropertyCache
var _skipset: _Set

# Collaborators
var _input_encoder: _RedundantHistoryEncoder
var _full_state_encoder: _SnapshotHistoryEncoder
var _diff_state_encoder: _DiffHistoryEncoder

# State
var _ackd_state: Dictionary = {}
var _next_full_state_tick: int
var _next_diff_ack_tick: int

var _earliest_input_tick: int
var _latest_state_tick: int

var _is_predicted_tick: bool
var _is_initialized: bool

# Signals
signal _on_transmit_state(state: Dictionary, tick: int)

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("RollbackHistoryTransmitter")

func get_earliest_input_tick() -> int:
	return _earliest_input_tick

func get_latest_state_tick() -> int:
	return _latest_state_tick

func set_predicted_tick(p_is_predicted_tick) -> void:
	_is_predicted_tick = p_is_predicted_tick

func sync_settings(p_root: Node, p_enable_input_broadcast: bool, p_full_state_interval: int, p_diff_ack_interval: int) -> void:
	root = p_root
	enable_input_broadcast = p_enable_input_broadcast
	full_state_interval = p_full_state_interval
	diff_ack_interval = p_diff_ack_interval

func configure(
		p_state_history: _PropertyHistoryBuffer, p_input_history: _PropertyHistoryBuffer,
		p_state_property_config: _PropertyConfig, p_input_property_config: _PropertyConfig,
		p_visibility_filter: PeerVisibilityFilter,
		p_property_cache: PropertyCache,
		p_skipset: _Set
	) -> void:
	_state_history = p_state_history
	_input_history = p_input_history
	_state_property_config = p_state_property_config
	_input_property_config = p_input_property_config
	_visibility_filter = p_visibility_filter
	_property_cache = p_property_cache
	_skipset = p_skipset

	_input_encoder = _RedundantHistoryEncoder.new(_input_history, _property_cache)
	_full_state_encoder = _SnapshotHistoryEncoder.new(_state_history, _property_cache)
	_diff_state_encoder = _DiffHistoryEncoder.new(_state_history, _property_cache)

	_is_initialized = true

	reset()

func reset() -> void:
	_ackd_state.clear()
	_latest_state_tick = NetworkTime.tick - 1
	_earliest_input_tick = NetworkTime.tick
	_next_full_state_tick = NetworkTime.tick
	_next_diff_ack_tick = NetworkTime.tick

	# Scatter full state sends, so not all nodes send at the same tick
	if is_inside_tree():
		_next_full_state_tick += hash(root.get_path()) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(root.get_path()) % maxi(1, diff_ack_interval)
	else:
		_next_full_state_tick += hash(root.name) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(root.name) % maxi(1, diff_ack_interval)

	_diff_state_encoder.add_properties(_state_property_config.get_properties())
	_full_state_encoder.set_properties(_get_owned_state_props())
	_input_encoder.set_properties(_get_owned_input_props())

func conclude_tick_loop() -> void:
	_earliest_input_tick = NetworkTime.tick

func transmit_input(tick: int) -> void:
	if not _get_owned_input_props().is_empty():
		var input_tick: int = tick + NetworkRollback.input_delay
		var input_data := _input_encoder.encode(input_tick, _get_owned_input_props())
		var state_owning_peer := root.get_multiplayer_authority()
		NetworkRollback.register_input_submission(root, tick)

		if enable_input_broadcast:
			for peer in _visibility_filter.get_rpc_target_peers():
				_submit_input.rpc_id(peer, input_tick, input_data)
		elif state_owning_peer != multiplayer.get_unique_id():
			_submit_input.rpc_id(state_owning_peer, input_tick, input_data)

func transmit_state(tick: int) -> void:
	if _get_owned_state_props().is_empty():
		# We don't own state, don't transmit anything
		return

	if _is_predicted_tick and not _input_property_config.get_properties().is_empty():
		# Don't transmit anything if we're predicting
		# EXCEPT when we're running inputless
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

	_latest_state_tick = max(_latest_state_tick, tick)

	var is_sending_diffs := NetworkRollback.enable_diff_states
	var is_full_state_tick := not is_sending_diffs or (full_state_interval > 0 and tick > _next_full_state_tick)

	if is_full_state_tick:
		# Broadcast new full state
		for peer in _visibility_filter.get_rpc_target_peers():
			_send_full_state(tick, peer)

		# Adjust next full state if sending diffs
		if is_sending_diffs:
			_next_full_state_tick = tick + full_state_interval
	else:
		# Send diffs to each peer
		for peer in _visibility_filter.get_visible_peers():
			var reference_tick := _ackd_state.get(peer, -1) as int
			if reference_tick < 0 or not _state_history.has(reference_tick):
				# Peer hasn't ack'd any tick, or we don't have the ack'd tick
				# Send full state
				_send_full_state(tick, peer)
				continue

			# Prepare diff
			var diff_state_data := _diff_state_encoder.encode(tick, reference_tick, _get_owned_state_props())
			
			if _diff_state_encoder.get_full_snapshot().size() == _diff_state_encoder.get_encoded_snapshot().size():
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
	if NetworkRollback.is_rollback_aware(property.node):
		return NetworkRollback.is_simulated(property.node)

	# Node is not rollback-aware, broadcast updates only if we own it
	return property.node.is_multiplayer_authority()

func _send_full_state(tick: int, peer: int = 0) -> void:
	var full_state_snapshot := _state_history.get_snapshot(tick).as_dictionary()
	var full_state_data := _full_state_encoder.encode(tick, _get_owned_state_props())

	_submit_full_state.rpc_id(peer, full_state_data, tick)

	if peer <= 0:
		NetworkPerformance.push_full_state_broadcast(full_state_snapshot)
		NetworkPerformance.push_sent_state_broadcast(full_state_snapshot)
	else:
		NetworkPerformance.push_full_state(full_state_snapshot)
		NetworkPerformance.push_sent_state(full_state_snapshot)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		NetworkRollback.free_input_submission_data_for(root)

@rpc("any_peer", "unreliable", "call_remote")
func _submit_input(tick: int, data: Array) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var sender := multiplayer.get_remote_sender_id()
	var snapshots := _input_encoder.decode(data, _input_property_config.get_properties_owned_by(sender))
	var earliest_received_input = _input_encoder.apply(tick, snapshots, sender)
	if earliest_received_input >= 0:
		_earliest_input_tick = mini(_earliest_input_tick, earliest_received_input)
		NetworkRollback.register_input_submission(root, tick)

# `serialized_state` is a serialized _PropertySnapshot
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_full_state(data: Array, tick: int) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var sender := multiplayer.get_remote_sender_id()
	var snapshot := _full_state_encoder.decode(data, _state_property_config.get_properties_owned_by(sender))
	if not _full_state_encoder.apply(tick, snapshot, sender):
		# Invalid data
		return

	_latest_state_tick = tick
	if NetworkRollback.enable_diff_states:
		_ack_full_state.rpc_id(sender, tick)

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

	if NetworkRollback.enable_diff_states:
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
