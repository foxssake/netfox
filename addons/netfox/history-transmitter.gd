extends Node
class_name _HistoryTransmitter

# Config
var full_state_interval: int = 24
var diff_ack_interval: int = 0

# Externally provided
var _history: _PropertyHistoryBuffer
var _property_config: _PropertyConfig
var _property_cache: PropertyCache

# State
var _ackd_state: Dictionary = {}
# Offset scheduled ack's and full ticks by this many ticks, so not all
# transmitters send big RPCs at once
var _tick_offset: int = 0

var _is_initialized: bool = false

# Collaborators
var _full_state_encoder: _SnapshotHistoryEncoder
var _diff_state_encoder: _DiffHistoryEncoder

var _logger := _NetfoxLogger.for_netfox("HistoryTransmitter")


func _init(p_history: _PropertyHistoryBuffer, p_property_config: _PropertyConfig, p_property_cache: PropertyCache):
	_history = p_history
	_property_config = p_property_config
	_property_cache = p_property_cache

	# Start with zero-intervals so nothing is done by default; wait for first process_settings()
	process_settings(_property_cache, 0, 0)

func process_settings(p_property_cache: PropertyCache, p_full_state_interval: int, p_diff_ack_interval: int) -> void:
	full_state_interval = p_full_state_interval
	diff_ack_interval = p_diff_ack_interval

	# TODO: Keep the same PropertyCache, so DiffHistoryEncoder can keep version tags of updates
	_full_state_encoder = _SnapshotHistoryEncoder.new(_history, _property_cache)
	_diff_state_encoder = _DiffHistoryEncoder.new(_history, _property_cache)

	_diff_state_encoder.add_properties(_property_config.get_properties())

func transmit(tick: int) -> void:
	var is_sending_diffs := NetworkRollback.enable_diff_states # TODO: Don't tie to a rollback setting?
	var is_full_state_tick := not is_sending_diffs or _is_full_state_cheduled_for(tick)

	if is_full_state_tick:
		# Broadcast new full state
		_send_full_state(tick)
		return

	# Send diffs to each peer
	for peer in multiplayer.get_peers():
		var reference_tick := _ackd_state.get(peer, -1) as int
		if reference_tick < 0 or not _history.has(reference_tick):
			# Peer hasn't ack'd any tick, or we don't have the ack'd tick
			# Send full state
			_logger.trace("Reference tick @%d not found for peer #%s, sending full tick", [reference_tick, peer])
			_send_full_state(tick, peer)
			continue

		# Prepare diff
		var diff_state_data := _diff_state_encoder.encode(tick, reference_tick, _property_config.get_properties())

		if _diff_state_encoder.get_full_snapshot().size() == _diff_state_encoder.get_encoded_snapshot().size():
			# State is completely different, send full state
			_send_full_state(tick, peer)
		else:
			# Send only diff
			_submit_diff_state.rpc_id(peer, diff_state_data, tick, reference_tick)

			# Push metrics
			NetworkPerformance.push_full_state(_diff_state_encoder.get_full_snapshot())
			NetworkPerformance.push_sent_state(_diff_state_encoder.get_encoded_snapshot())

func _send_full_state(tick: int, peer: int = 0) -> void:
	var full_state_snapshot := _history.get_snapshot(tick).as_dictionary()
	var full_state_data := _full_state_encoder.encode(tick, _property_config.get_properties())

	if peer == 0:
		_submit_full_state.rpc(full_state_data, tick)
	else:
		_submit_full_state.rpc_id(peer, full_state_data, tick)

	NetworkPerformance.push_full_state(full_state_snapshot)
	NetworkPerformance.push_sent_state(full_state_snapshot)

func _calculate_tick_offset() -> int:
	if is_inside_tree():
		return hash(get_path()) % maxi(1, full_state_interval)
	else:
		# Find list of parents and hash that path
		var path := [self]
		while true:
			var at := path.back() as Node
			var parent := at.get_parent()
			if parent == null:
				break
			path.push_back(parent)

		return hash(path) % maxi(1, full_state_interval)

func _is_full_state_cheduled_for(tick: int) -> bool:
	return full_state_interval > 0 and ((tick - _tick_offset) % full_state_interval) == 0

func _is_diff_ack_scheduled_for(tick: int) -> bool:
	return diff_ack_interval > 0 and ((tick - _tick_offset) % diff_ack_interval) == 0

# `serialized_state` is a serialized _PropertySnapshot
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_full_state(data: Array, tick: int) -> void:
#	if not _is_initialized: return

	var sender := multiplayer.get_remote_sender_id()
	var snapshot := _full_state_encoder.decode(data, _property_config.get_properties_owned_by(sender))
	
	if not _full_state_encoder.apply(tick, snapshot, sender):
		# Invalid data
		return

	if NetworkRollback.enable_diff_states:
		_ack_full_state.rpc_id(sender, tick)

# State is a serialized _PropertySnapshot (Dictionary[String, Variant])
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_diff_state(data: PackedByteArray, tick: int, reference_tick: int) -> void:
#	if not _is_initialized: return

	var sender = multiplayer.get_remote_sender_id()
	var diff_snapshot := _diff_state_encoder.decode(data, _property_config.get_properties_owned_by(sender))
	if not _diff_state_encoder.apply(tick, diff_snapshot, reference_tick, sender):
		# Invalid data
		return

	if NetworkRollback.enable_diff_states and _is_diff_ack_scheduled_for(tick):
		_ack_diff_state.rpc_id(sender, tick)

@rpc("any_peer", "reliable", "call_remote")
func _ack_full_state(tick: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd full state for tick %d", [sender_id, tick])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _ack_diff_state(tick: int) -> void:
	if not _is_initialized: return

	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd diff state for tick %d", [sender_id, tick])

