extends "res://addons/netfox/rollback/layers/3-snapshot-rollback-layer.gd"

## Ticks to wait between sending full states.
## [br][br]
## If set to 0, full states will never be sent. If set to 1, only full states
## will be sent. If set higher, full states will be sent regularly, but not
## for every tick.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var full_state_interval: int = 24

## Ticks to wait between unreliably acknowledging diff states.
## [br][br]
## This can reduce the amount of properties sent in diff states, due to clients
## more often acknowledging received states. To avoid introducing hickups, these
## are sent unreliably.
## [br][br]
## If set to 0, diff states will never be acknowledged. If set to 1, all diff
## states will be acknowledged. If set higher, ack's will be sent regularly, but
## not for every diff state.
## [br][br]
## If enabled, it's worth to tune this setting until network traffic is actually
## reduced.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var diff_ack_interval: int = 0

## This will broadcast input to all peers, turning this off will limit to
## sending it to the server only. Turning this off is recommended to save
## bandwidth and reduce cheating risks.
@export var enable_input_broadcast: bool = true

var _input_encoder := _RedundantHistoryEncoder.new(_inputs, _property_cache)
var _full_state_encoder := _SnapshotHistoryEncoder.new(_states, _property_cache)
var _diff_state_encoder := _DiffHistoryEncoder.new(_states, _property_cache)

# Maps peers (int) to acknowledged ticks (int)
var _ackd_state: Dictionary = {}
var _next_full_state_tick: int
var _next_diff_ack_tick: int

signal _on_transmit_state(state: Dictionary, tick: int)

func _connect_signals() -> void:
	super()
	NetworkTime.after_tick.connect(_sync_input)
	NetworkRollback.on_record_tick.connect(_broadcast_tick)

func _disconnect_signals() -> void:
	super()
	NetworkTime.after_tick.disconnect(_sync_input)
	NetworkRollback.on_record_tick.disconnect(_broadcast_tick)

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

	_latest_state_tick = max(_latest_state_tick, tick)
	_states.merge(full_state, tick)

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
			if reference_tick < 0 or not _states.has(reference_tick):
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
	var full_state_snapshot := _states.get_snapshot(tick).as_dictionary()
	var full_state_data := _full_state_encoder.encode(tick, _get_owned_state_props())

	if peer == 0:
		_submit_full_state.rpc(full_state_data, tick)

		NetworkPerformance.push_full_state_broadcast(full_state_snapshot)
		NetworkPerformance.push_sent_state_broadcast(full_state_snapshot)
	else:
		_submit_full_state.rpc_id(peer, full_state_data, tick)

		NetworkPerformance.push_full_state(full_state_snapshot)
		NetworkPerformance.push_sent_state(full_state_snapshot)

func _sync_input(_delta: float, _tick: int) -> void:
	# Record input
	if not _get_recorded_input_props().is_empty():
		# TODO: Separate
		var input = _PropertySnapshot.extract(_get_recorded_input_props())
		var input_tick: int = _tick + NetworkRollback.input_delay
		_inputs.set_snapshot(input_tick, input)

		# Transmit input
		var input_data := _input_encoder.encode(input_tick, _get_owned_input_props())
		var target_peer := 0 if enable_input_broadcast else root.get_multiplayer_authority()
		if target_peer != multiplayer.get_unique_id():
			_submit_input.rpc_id(target_peer, input_tick, input_data)

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
