@tool
extends Node
class_name StateSynchronizer

## Synchronizes state from authority.
##
## Similar to Godot's [MultiplayerSynchronizer], but is tied to the network tick loop. Works well
## with [TickInterpolator].
## [br][br]
## @tutorial(StateSynchronizer Guide): https://foxssake.github.io/netfox/latest/netfox/nodes/state-synchronizer/

## The root node for resolving node paths in properties.
@export var root: Node

## Properties to record and broadcast.
@export var properties: Array[String]

## Ticks to wait between sending full states.
## [br][br]
## If set to 0, full states will never be sent. If set to 1, only full states
## will be sent. If set higher, full states will be sent regularly, but not
## for every tick.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var full_state_interval: int = 24 # TODO: Don't tie to a network rollback setting?

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
var diff_ack_interval: int = 0 # TODO: Don't tie to a network rollback setting?

## Decides which peers will receive updates
var visibility_filter := PeerVisibilityFilter.new()

var _property_cache: PropertyCache
var _property_config: _PropertyConfig = _PropertyConfig.new()
var _properties_dirty: bool = false

var _state_history := _PropertyHistoryBuffer.new()

# Collaborators
var _full_state_encoder: _SnapshotHistoryEncoder
var _diff_state_encoder: _DiffHistoryEncoder

# State
var _ackd_state: Dictionary = {}
var _next_full_state_tick: int
var _next_diff_ack_tick: int

var _is_initialized: bool = false

static var _logger := NetfoxLogger._for_netfox("StateSynchronizer")

## Process settings.
## [br][br]
## Call this after any change to configuration.
func process_settings() -> void:
	_property_cache = PropertyCache.new(root)
	_property_config.set_properties_from_paths(properties, _property_cache)

	_full_state_encoder = _SnapshotHistoryEncoder.new(_state_history, _property_cache)
	_diff_state_encoder = _DiffHistoryEncoder.new(_state_history, _property_cache)

	_diff_state_encoder.add_properties(_property_config.get_properties())

	_next_full_state_tick = NetworkTime.tick
	_next_diff_ack_tick = NetworkTime.tick

	# Scatter full state sends, so not all nodes send at the same tick
	if is_inside_tree():
		_next_full_state_tick += hash(root.get_path()) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(root.get_path()) % maxi(1, diff_ack_interval)
	else:
		_next_full_state_tick += hash(root.name) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(root.name) % maxi(1, diff_ack_interval)

	_is_initialized = true

## Add a state property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_state(node: Variant, property: String) -> void:
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or properties.has(property_path):
		return

	properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

func _notification(what) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()

	# Explore state properties
	if not root:
		return ["No valid root node found!"]

	return _NetfoxEditorUtils.gather_properties(root, "_get_synchronized_state_properties",
		func(node, prop):
			add_state(node, prop)
	)

func _connect_signals() -> void:
	NetworkTime.after_tick.connect(_after_tick)
	NetworkTime.after_tick_loop.connect(_after_loop)

func _disconnect_signals() -> void:
	NetworkTime.after_tick.disconnect(_after_tick)
	NetworkTime.after_tick_loop.disconnect(_after_loop)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()
	if not visibility_filter.get_parent():
		add_child(visibility_filter)

	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_signals()

func _after_tick(_dt: float, tick: int) -> void:
	if is_multiplayer_authority():
		# Submit snapshot
		var state := _PropertySnapshot.extract(_property_config.get_properties())
		_state_history.set_snapshot(tick, state)
		_broadcast_state(tick, state)
	elif not _state_history.is_empty():
		var state := _state_history.get_history(tick)
		state.apply(_property_cache)

func _after_loop() -> void:
	_state_history.trim(NetworkTime.tick - NetworkRollback.history_limit) # TODO: Don't tie to rollback?

func _reprocess_settings() -> void:
	if not _properties_dirty:
		return

	_properties_dirty = false
	process_settings()

func _broadcast_state(tick: int, state: _PropertySnapshot) -> void:
	var is_sending_diffs := NetworkRollback.enable_diff_states # TODO: Don't tie to a rollback setting?
	var is_full_state_tick := not is_sending_diffs or (full_state_interval > 0 and tick > _next_full_state_tick)

	if is_full_state_tick:
		# Broadcast new full state
		for peer in visibility_filter.get_rpc_target_peers():
			_send_full_state(tick, peer)

		# Adjust next full state if sending diffs
		if is_sending_diffs:
			_next_full_state_tick = tick + full_state_interval
	else:
		# Send diffs to each peer
		for peer in visibility_filter.get_visible_peers():
			var reference_tick := _ackd_state.get(peer, -1) as int
			if reference_tick < 0 or not _state_history.has(reference_tick):
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
	var full_state_snapshot := _state_history.get_snapshot(tick).as_dictionary()
	var full_state_data := _full_state_encoder.encode(tick, _property_config.get_properties())

	_submit_full_state.rpc_id(peer, full_state_data, tick)

	if peer <= 0:
		NetworkPerformance.push_full_state_broadcast(full_state_snapshot)
		NetworkPerformance.push_sent_state_broadcast(full_state_snapshot)
	else:
		NetworkPerformance.push_full_state(full_state_snapshot)
		NetworkPerformance.push_sent_state(full_state_snapshot)

# `serialized_state` is a serialized _PropertySnapshot
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_full_state(data: Array, tick: int) -> void:
	if not _is_initialized: return

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
	if not _is_initialized: return

	var sender = multiplayer.get_remote_sender_id()
	var diff_snapshot := _diff_state_encoder.decode(data, _property_config.get_properties_owned_by(sender))
	if not _diff_state_encoder.apply(tick, diff_snapshot, reference_tick, sender):
		# Invalid data
		return

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
	if not _is_initialized: return

	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd diff state for tick %d", [sender_id, tick])
