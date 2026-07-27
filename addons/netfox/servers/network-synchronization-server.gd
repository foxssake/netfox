extends Node
class_name _NetworkSynchronizationServer

# @public class

## Synchronizes properties over the network
##
## Handles synchronization of rollback and state properties (
## [RollbackSynchronizer] and [StateSynchronizer] ), while respecting visibility
## filters and schemas for serialization.
## [br][br]
## Packets are sent per tick, instead of per object. So for every simulated
## rollback tick, a packet is sent with states, and for every recorded input,
## a packet is sent with the inputs.
## [br][br]
## Optionally, diff states can be used, sending only the property values that
## have changed, saving on bandwidth.

# Dependencies
var _command_server: _NetworkCommandServer
var _history_server: _NetworkHistoryServer
var _identity_server: _NetworkIdentityServer
var _simulation_server: _RollbackSimulationServer

# Configuration
var _rb_input_properties := _PropertyPool.new()
var _rb_state_properties := _PropertyPool.new()
var _rb_owned_input_properties := _PropertyPool.new()
var _rb_owned_state_properties := _PropertyPool.new()
var _sync_state_properties := _PropertyPool.new()
var _sync_owned_state_properties := _PropertyPool.new()

var _visibility_filters := {} # Node to PeerVisibilityFilter

var _rb_enable_input_broadcast := ProjectSettings.get_setting("netfox/rollback/enable_input_broadcast", false) as bool
var _rb_enable_diffs := NetworkRollback.enable_diff_states
var _rb_full_interval := ProjectSettings.get_setting("netfox/rollback/full_state_interval", 24) as int
var _rb_full_scheduler := _IntervalScheduler.new(_rb_full_interval)

var _input_redundancy := NetworkRollback.input_redundancy

var _rb_sent_state_history := {} # peer to _HistoryBuffer of _Snapshot

var _last_sync_state_sent := _Snapshot.new(0)
var _sync_enable_diffs := ProjectSettings.get_setting("netfox/state_synchronizer/enable_diff_states", true) as bool
var _sync_full_interval := ProjectSettings.get_setting("netfox/state_synchronizer/full_state_interval", 24) as int
var _sync_full_scheduler := _IntervalScheduler.new(_sync_full_interval)

# Very conservative packet size limit, source:
# https://stackoverflow.com/a/35697810
var _max_packet_size := ProjectSettings.get_setting("netfox/general/max_sync_packet_size", 508) as int

var _schemas := _NetworkSchema.new()

var _dense_serializer: _DenseSnapshotSerializer
var _sparse_serializer: _SparseSnapshotSerializer
var _redundant_serializer: _RedundantSnapshotSerializer

var _cmd_full_state: NetworkCommandServer.Command
var _cmd_diff_state: NetworkCommandServer.Command
var _cmd_input: NetworkCommandServer.Command

var _cmd_full_sync: NetworkCommandServer.Command
var _cmd_diff_sync: NetworkCommandServer.Command

static var _logger := NetfoxLogger._for_netfox("NetworkSynchronizationServer")

signal _on_input(snapshot: _Snapshot)
signal _on_state(snapshot: _Snapshot)

## Register a [param property] of [param node] to be synchronized
## as rollback state
func register_rollback_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.add(node, property)
	if node.is_multiplayer_authority():
		_rb_owned_state_properties.add(node, property)

## Deregister a [param property] of [param node] from being
## synchronized as rollback state
func deregister_rollback_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.erase(node, property)
	_rb_owned_state_properties.erase(node, property)

## Register a [param property] of [param node] to be synchronized
## as rollback input
func register_rollback_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.add(node, property)
	if node.is_multiplayer_authority():
		_rb_owned_input_properties.add(node, property)

## Deregister a [param property] of [param node] from being
## synchronized as rollback input
func deregister_rollback_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.erase(node, property)
	_rb_owned_input_properties.erase(node, property)

## Register a [param property] of [param node] to be synchronized
## as synchronized state
func register_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.add(node, property)
	if node.is_multiplayer_authority():
		_sync_owned_state_properties.add(node, property)

## Deregister a [param property] of [param node] from being
## synchronized as synchronized state
func deregister_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.erase(node, property)
	_sync_owned_state_properties.erase(node, property)

## Register a [param serializer] to use when transmitting
## [param property param] of [param node] over the network
func register_schema(node: Node, property: NodePath, serializer: NetworkSchemaSerializer) -> void:
	_schemas.add(node, property, serializer)

## Deregister any serializers used for [param property] on
## [param node] when transmitting over the network
func deregister_schema(node: Node, property: NodePath) -> void:
	_schemas.erase(node, property)

## Deregister all serializers registered for any properties of
## [param node]
func deregister_schema_for(node: Node) -> void:
	_schemas.erase_subject(node)

## Register a visibility [param filter] for use with [param node]
func register_visibility_filter(node: Node, filter: PeerVisibilityFilter) -> void:
	_visibility_filters[node] = filter

## Deregister the visibility filter used for [param node]
func deregister_visibility_filter(node: Node) -> void:
	_visibility_filters.erase(node)

## Deregister any and all settings associated with [param node]
func deregister(node: Node) -> void:
	_rb_state_properties.erase_subject(node)
	_rb_input_properties.erase_subject(node)
	_rb_owned_state_properties.erase_subject(node)
	_rb_owned_input_properties.erase_subject(node)
	_sync_state_properties.erase_subject(node)
	_sync_owned_state_properties.erase_subject(node)
	_visibility_filters.erase(node)
	_schemas.erase_subject(node)

	# NOTE: _rb_sent_state_history may contain snapshots with invalid subjects
	# NOTE: Iterating all sent snapshots for `node` may be slow and useless

## Erase all data kept about [param peer].
## [br][br]
## Called by default when a peer leaves
func erase_peer(peer: int) -> void:
	_rb_sent_state_history.erase(peer)

func _get_peer_rb_sent_history(peer: int) -> _HistoryBuffer:
	if not _rb_sent_state_history.has(peer):
		_rb_sent_state_history[peer] = _HistoryBuffer.new(NetworkRollback.history_limit)
	return _rb_sent_state_history[peer]

func _get_last_sent_rollback_state(peer: int, tick: int) -> _Snapshot:
	var history: _HistoryBuffer = _rb_sent_state_history.get(peer, null)
	if history == null or not history.has_latest_at(tick):
		return null
	return history.get_latest_at(tick)

func _remember_sent_rollback_state(peer: int, snapshot: _Snapshot) -> void:
	var reference := _get_last_sent_rollback_state(peer, snapshot.tick)
	var remembered := reference.duplicate() if reference else _Snapshot.new(snapshot.tick)

	# `snapshot` might be a diff state, hence the merging
	for subject in snapshot.get_subjects():
		for property in snapshot.get_subject_properties(subject):
			remembered.set_property(subject, property, snapshot.get_property(subject, property))
		remembered.set_auth(subject, snapshot.is_auth(subject))
	remembered.tick = snapshot.tick

	_get_peer_rb_sent_history(peer).set_at(snapshot.tick, remembered)

# Prepare snapshot to be sent to `peer`
# Only contains visible subjects' auth properties
func _make_peer_snapshot(snapshot: _Snapshot, peer: int, properties: _PropertyPool) -> _Snapshot:
	var result := _Snapshot.new(snapshot.tick)
	for subject in properties.get_subjects():
		if not _is_node_visible_to(peer, subject):
			continue
		if not snapshot.is_auth(subject):
			continue

		var has_property := false
		for property in properties.get_properties_of(subject):
			if not snapshot.has_property(subject, property):
				continue
			result.set_property(subject, property, snapshot.get_property(subject, property))
			has_property = true

		if has_property:
			result.set_auth(subject, true)
	return result

func _is_node_visible_to(peer: int, node: Node) -> bool:
	var filter := _visibility_filters.get(node) as PeerVisibilityFilter
	if not filter:
		return true
	else:
		return filter.get_visible_peers().has(peer)

func _synchronize_input(tick: int) -> void:
	# We don't own inputs, nothing to synchronize
	if _rb_owned_input_properties.is_empty():
		return

	var snapshots := [] as Array[_Snapshot]
	var notified_peers := _Set.new()

	if not _rb_enable_input_broadcast:
		# If input broadcast is off, find which peers need to know our inputs
		# That is all peers who own state controlled by our input

		# Grab owned input objects
		for input_subject in _rb_owned_input_properties.get_subjects():
			# Grab state objects controlled by input
			var controlled_nodes := RollbackSimulationServer._get_controlled_by(input_subject)

			# Notify peers owning nodes about the input
			for node in controlled_nodes:
				notified_peers.add(node.get_multiplayer_authority())
	else:
		# If input broadcast is on, send inputs to everyone
		for peer in multiplayer.get_peers():
			notified_peers.add(peer)

	# Make sure to not send input to ourselves
	notified_peers.erase(multiplayer.get_unique_id())

	# Prepare snapshot package
	for offset in _input_redundancy:
		# Grab snapshot from NetworkHistoryServer
		var snapshot := NetworkHistoryServer._get_rollback_input_snapshot(tick - offset)
		if not snapshot:
			break

		_logger.trace("Submitting input: %s", [snapshot])
		snapshots.append(snapshot)

	_logger.trace("Submitting input to peers: %s", [notified_peers])
	for peer in notified_peers:
		var data := _redundant_serializer.write_for(peer, snapshots, _rb_owned_input_properties)
		_cmd_input.send(data, peer)

func _synchronize_state(tick: int) -> void:
	# We don't own state, nothing to synchronize
	if _rb_owned_state_properties.is_empty():
		return

	# Grab snapshot from NetworkHistoryServer
	var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(tick)
	if not snapshot:
		# No data for tick
		return

	if snapshot.is_empty():
		# Nothing to send
		return

	# Figure out whether to send full- or diff state
	var is_full := _rb_full_scheduler.is_now()
	if not _rb_enable_diffs:
		is_full = true

	for peer in multiplayer.get_peers():
		var peer_snapshot := _make_peer_snapshot(snapshot, peer, _rb_owned_state_properties)
		if peer_snapshot.is_empty():
			continue

		var peer_is_full := is_full
		var reference_snapshot := _get_last_sent_rollback_state(peer, tick)
		if reference_snapshot == null:
			peer_is_full = true

		if peer_is_full:
			var packets := _dense_serializer.write_for(peer, peer_snapshot, _rb_owned_state_properties)
			for packet in packets:
				_cmd_full_state.send(packet, peer)

			_remember_sent_rollback_state(peer, peer_snapshot)
			NetworkPerformance.push_full_state_props(peer_snapshot.size())
			NetworkPerformance.push_sent_state_props(peer_snapshot.size())
		else:
			var diff := _Snapshot.make_patch(reference_snapshot, peer_snapshot)
			if diff.is_empty():
				# Nothing changed, don't send anything
				continue

			var packets := _sparse_serializer.write_for(peer, diff, _rb_owned_state_properties)
			for packet in packets:
				_cmd_diff_state.send(packet, peer)

			_remember_sent_rollback_state(peer, diff)
			NetworkPerformance.push_full_state_props(peer_snapshot.size())
			NetworkPerformance.push_sent_state_props(diff.size())

func _synchronize_sync_state(tick: int) -> void:
	# We don't own sync state, nothing to synchronize
	if _sync_owned_state_properties.is_empty():
		return

	# Grab snapshot from NetworkHistoryServer
	var snapshot := NetworkHistoryServer._get_synchronizer_state_snapshot(tick)
	if not snapshot:
		return

	# Figure out whether to send full- or diff state
	var is_full := _sync_full_scheduler.is_now()
	if not _sync_enable_diffs:
		is_full = true

	if is_full:
		# Send full states
		for peer in multiplayer.get_peers():
			var filter := func(subject): return _is_node_visible_to(peer, subject)

			var packets := _dense_serializer.write_for(peer, snapshot, _sync_owned_state_properties, filter)
			for packet in packets:
				_cmd_full_sync.send(packet, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(snapshot.size())
	else:
		var diff := _Snapshot.make_patch(_last_sync_state_sent, snapshot)

		# Send diffs
		for peer in multiplayer.get_peers():
			var filter := func(subject): return _is_node_visible_to(peer, subject)

			var packets := _sparse_serializer.write_for(peer, diff, _sync_owned_state_properties, filter)
			for packet in packets:
				_cmd_diff_sync.send(packet, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(diff.size())

	# Remember last sent state for diffing
	# NOTE: This is a shared instance, theoretically shouldn't screw things up
	_last_sync_state_sent = snapshot

func _init(
		p_command_server: _NetworkCommandServer = null,
		p_history_server: _NetworkHistoryServer = null,
		p_identity_server: _NetworkIdentityServer = null,
		p_simulation_server: _RollbackSimulationServer = null
	):
	_command_server = p_command_server
	_history_server = p_history_server
	_identity_server = p_identity_server
	_simulation_server = p_simulation_server

func _ready():
	# Ensure dependencies
	if not _command_server: _command_server = NetworkCommandServer
	if not _history_server: _history_server = NetworkHistoryServer
	if not _identity_server: _identity_server = NetworkIdentityServer
	if not _simulation_server: _simulation_server = RollbackSimulationServer

	# Setup serializers
	_dense_serializer = _DenseSnapshotSerializer.new(_schemas, _identity_server)
	_sparse_serializer = _SparseSnapshotSerializer.new(_schemas, _identity_server)
	_redundant_serializer = _RedundantSnapshotSerializer.new(_schemas, _identity_server)

	_dense_serializer.max_packet_size = _max_packet_size
	_sparse_serializer.max_packet_size = _max_packet_size
	_redundant_serializer.max_packet_size = _max_packet_size

	# Setup commands
	_cmd_full_state = _command_server.register_command(_handle_full_state, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_cmd_diff_state = _command_server.register_command(_handle_diff_state, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	_cmd_input = _command_server.register_command(_handle_input, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

	_cmd_full_sync = _command_server.register_command(_handle_full_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	_cmd_diff_sync = _command_server.register_command(_handle_diff_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)

	# Cleanup
	if NetworkEvents.enabled:
		NetworkEvents.on_peer_leave.connect(erase_peer)
	elif is_instance_valid(multiplayer):
		multiplayer.peer_disconnected.connect(erase_peer)

func _handle_input(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshots := _redundant_serializer.read_from(sender, _rb_input_properties, buffer, true)

	for snapshot in snapshots:
		snapshot.sanitize(sender)

		_logger.trace("Ingesting input: %s", [snapshot])
		if NetworkHistoryServer._merge_rollback_input(snapshot):
			_on_input.emit(snapshot)

func _handle_full_state(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _dense_serializer.read_from(sender, _rb_state_properties, buffer, true)

	_ingest_state(sender, snapshot)

func _handle_diff_state(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var diff := _sparse_serializer.read_from(sender, _rb_state_properties, buffer)
	_logger.trace("Received diff state for @%d", [diff.tick])

	_ingest_state(sender, diff)

func _handle_full_sync(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _dense_serializer.read_from(sender, _sync_state_properties, buffer, true)
	snapshot.sanitize(sender)

	NetworkHistoryServer._merge_synchronizer_state(snapshot)
	_logger.trace("Ingested sync state: %s", [snapshot])

func _handle_diff_sync(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _sparse_serializer.read_from(sender, _sync_state_properties, buffer)
	snapshot.sanitize(sender)

	NetworkHistoryServer._merge_synchronizer_state(snapshot)
	_logger.trace("Ingested sync diff: %s", [snapshot])

func _ingest_state(sender: int, snapshot: _Snapshot) -> void:
	snapshot.sanitize(sender)

	NetworkHistoryServer._merge_rollback_state(snapshot)
	_logger.trace("Ingested state: %s", [snapshot])

	_on_state.emit(snapshot)
