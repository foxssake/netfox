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

var _cmd_inputs_complete: NetworkCommandServer.Command
var _latest_input_tick_by_peer := {}
var _expected_input_start_tick_by_peer := {}
var _remote_input_peers := {} as Dictionary
var _remote_input_peers_dirty: bool = true
var _local_latest_inputs_complete_tick := -1
var _latest_inputs_complete_tick := -1
var _last_sent_inputs_complete_tick := -1
var _latest_inputs_complete_tick_by_peer := {}

static var _logger := NetfoxLogger._for_netfox("NetworkSynchronizationServer")

signal _on_input(snapshot: _Snapshot)
signal _on_state(snapshot: _Snapshot)

## Register a [param property] of [param node] to be synchronized
## as rollback state
func register_rollback_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.add(node, property)
	if node.is_multiplayer_authority():
		_rb_owned_state_properties.add(node, property)

	_remote_input_peers_dirty = true
	_last_sent_inputs_complete_tick = -1
	_compute_local_latest_inputs_complete_tick()

## Deregister a [param property] of [param node] from being
## synchronized as rollback state
func deregister_rollback_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.erase(node, property)
	_rb_owned_state_properties.erase(node, property)

	_remote_input_peers_dirty = true
	_last_sent_inputs_complete_tick = -1
	_compute_local_latest_inputs_complete_tick()

## Register a [param property] of [param node] to be synchronized
## as rollback input
func register_rollback_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.add(node, property)
	if node.is_multiplayer_authority():
		_rb_owned_input_properties.add(node, property)

	_remote_input_peers_dirty = true
	_compute_local_latest_inputs_complete_tick()

## Deregister a [param property] of [param node] from being
## synchronized as rollback input
func deregister_rollback_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.erase(node, property)
	_rb_owned_input_properties.erase(node, property)

	_remote_input_peers_dirty = true
	_compute_local_latest_inputs_complete_tick()

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

## Return the latest tick for which all remote peers with registered rollback
## input owned by them have submitted input to this peer.
func get_latest_inputs_complete_tick() -> int:
	return _latest_inputs_complete_tick

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

	_remote_input_peers_dirty = true
	_last_sent_inputs_complete_tick = -1
	_compute_local_latest_inputs_complete_tick()

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

	_compute_local_latest_inputs_complete_tick()

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

	# Check if we have history to diff to
	var reference_snapshot := NetworkHistoryServer._get_rollback_state_snapshot(tick - 1)
	if not reference_snapshot:
		is_full = true

	if is_full:
		# Send full states
		for peer in multiplayer.get_peers():
			var filter := func(subject): return _is_node_visible_to(peer, subject)

			var packets := _dense_serializer.write_for(peer, snapshot, _rb_owned_state_properties, filter)
			for packet in packets:
				_cmd_full_state.send(packet, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(snapshot.size())
	else:
		var diff := _Snapshot.make_patch(reference_snapshot, snapshot)
		if diff.is_empty():
			# Nothing changed, don't send anything
			return

		# Send diff states
		for peer in multiplayer.get_peers():
			var filter := func(subject): return _is_node_visible_to(peer, subject)

			var packets := _sparse_serializer.write_for(peer, diff, _rb_owned_state_properties, filter)
			for packet in packets:
				_cmd_diff_state.send(packet, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
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
	_cmd_inputs_complete = _command_server.register_command(_handle_inputs_complete, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

	_cmd_full_sync = _command_server.register_command(_handle_full_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	_cmd_diff_sync = _command_server.register_command(_handle_diff_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)

func _handle_input(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshots := _redundant_serializer.read_from(sender, _rb_input_properties, buffer, true)

	for snapshot in snapshots:
		snapshot.sanitize(sender)

		_logger.trace("Ingesting input: %s", [snapshot])
		_track_remote_input(sender, snapshot)
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

func _handle_inputs_complete(sender: int, data: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	_latest_inputs_complete_tick_by_peer[sender] = buffer.get_u32()
	_compute_latest_inputs_complete_tick()

func _ingest_state(sender: int, snapshot: _Snapshot) -> void:
	snapshot.sanitize(sender)

	NetworkHistoryServer._merge_rollback_state(snapshot)
	_logger.trace("Ingested state: %s", [snapshot])

	_on_state.emit(snapshot)

func _track_remote_input(sender: int, snapshot: _Snapshot) -> void:
	if snapshot.is_empty():
		return

	var latest_tick: int = _latest_input_tick_by_peer.get(sender, -1)
	if snapshot.tick <= latest_tick:
		return

	_latest_input_tick_by_peer[sender] = snapshot.tick
	_compute_local_latest_inputs_complete_tick()


func _compute_local_latest_inputs_complete_tick() -> void:
	if _rb_owned_state_properties.is_empty():
		_set_local_latest_inputs_complete_tick(-1)
		return

	_compute_remote_input_peers_cache_if_needed()

	var inputs_complete: int = NetworkTime.tick
	var has_expected_peers := false

	for peer in _remote_input_peers.keys():
		has_expected_peers = true
		if not _latest_input_tick_by_peer.has(peer):
			var expected_since_tick: int = _expected_input_start_tick_by_peer.get(peer, NetworkTime.tick)
			inputs_complete = mini(inputs_complete, expected_since_tick - 1)
			continue
		inputs_complete = mini(inputs_complete, _latest_input_tick_by_peer[peer])

	if not has_expected_peers:
		_set_local_latest_inputs_complete_tick(NetworkTime.tick)
		return

	_set_local_latest_inputs_complete_tick(inputs_complete)


func _set_local_latest_inputs_complete_tick(tick: int) -> void:
	_local_latest_inputs_complete_tick = tick
	_compute_latest_inputs_complete_tick()

	if _rb_owned_state_properties.is_empty():
		return
	if _last_sent_inputs_complete_tick == tick:
		return

	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(tick)
	for peer in multiplayer.get_peers():
		_cmd_inputs_complete.send(buffer.data_array, peer)
	_last_sent_inputs_complete_tick = tick


func _set_latest_inputs_complete_tick(tick: int) -> void:
	_local_latest_inputs_complete_tick = tick
	_latest_inputs_complete_tick = tick


func _compute_latest_inputs_complete_tick() -> void:
	var authority_peers := _get_state_authority_peers()
	if authority_peers.is_empty():
		_latest_inputs_complete_tick = -1
		return

	var inputs_complete: int = NetworkTime.tick
	for peer in authority_peers:
		if peer == multiplayer.get_unique_id():
			if _local_latest_inputs_complete_tick < 0:
				_latest_inputs_complete_tick = -1
				return
			inputs_complete = mini(inputs_complete, _local_latest_inputs_complete_tick)
			continue

		if not _latest_inputs_complete_tick_by_peer.has(peer):
			_latest_inputs_complete_tick = -1
			return

		inputs_complete = mini(inputs_complete, _latest_inputs_complete_tick_by_peer[peer])

	_latest_inputs_complete_tick = inputs_complete


func _get_state_authority_peers() -> Array[int]:
	var peers := [] as Array[int]
	for subject in _rb_state_properties.get_subjects():
		if not is_instance_valid(subject):
			continue

		var peer: int = subject.get_multiplayer_authority()
		if peers.has(peer):
			continue

		peers.append(peer)

	return peers


func _compute_remote_input_peers_cache_if_needed() -> void:
	if not _remote_input_peers_dirty:
		return

	var previous_peers := _remote_input_peers.keys()
	var peers_changed: bool = false
	_remote_input_peers.clear()
	for subject in _rb_input_properties.get_subjects():
		if not is_instance_valid(subject):
			continue

		var peer: int = subject.get_multiplayer_authority()
		if peer == multiplayer.get_unique_id():
			continue

		_remote_input_peers[peer] = true

	for peer in _remote_input_peers.keys():
		if not previous_peers.has(peer):
			peers_changed = true
			_expected_input_start_tick_by_peer[peer] = NetworkTime.tick

	for peer in _expected_input_start_tick_by_peer.keys():
		if _remote_input_peers.has(peer):
			continue
		peers_changed = true
		_expected_input_start_tick_by_peer.erase(peer)

	_remote_input_peers_dirty = false

	if peers_changed:
		_last_sent_inputs_complete_tick = -1
