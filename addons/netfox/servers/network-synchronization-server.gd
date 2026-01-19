extends Node
class_name _NetworkSynchronizationServer

var _rb_input_properties := _PropertyPool.new()
var _rb_state_properties := _PropertyPool.new()
var _rb_owned_input_properties := _PropertyPool.new()
var _rb_owned_state_properties := _PropertyPool.new()
var _sync_state_properties := _PropertyPool.new()
var _sync_owned_state_properties := _PropertyPool.new()

var _visibility_filters := {} # Node to PeerVisibilityFilter

var _rb_enable_input_broadcast := ProjectSettings.get_setting("netfox/rollback/enable_input_broadcast", false)
var _rb_enable_diffs := NetworkRollback.enable_diff_states
var _rb_full_interval := ProjectSettings.get_setting("netfox/rollback/full_state_interval", 24)
var _rb_full_scheduler := _IntervalScheduler.new(_rb_full_interval)

var _last_sync_state_sent := Snapshot.new(0)
var _sync_enable_diffs := ProjectSettings.get_setting("netfox/state_synchronizer/enable_diff_states", true)
var _sync_full_interval := ProjectSettings.get_setting("netfox/state_synchronizer/full_state_interval", 24)
var _sync_full_scheduler := _IntervalScheduler.new(_sync_full_interval)

var _schemas := _NetworkSchema.new()

var _input_redundancy := NetworkRollback.input_redundancy

var _dense_serializer := _DenseSnapshotSerializer.new(_schemas)
var _sparse_serializer := _SparseSnapshotSerializer.new(_schemas)
var _redundant_serializer := _RedundantSnapshotSerializer.new(_schemas)

@onready var _cmd_full_state := NetworkCommandServer.register_command_at(_NetworkCommands.RB_FULL_STATE, _handle_full_state, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
@onready var _cmd_diff_state := NetworkCommandServer.register_command_at(_NetworkCommands.RB_DIFF_STATE, _handle_diff_state, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
@onready var _cmd_input := NetworkCommandServer.register_command_at(_NetworkCommands.INPUT, _handle_input, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

@onready var _cmd_full_sync := NetworkCommandServer.register_command_at(_NetworkCommands.SYNC_FULL, _handle_full_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
@onready var _cmd_diff_sync := NetworkCommandServer.register_command_at(_NetworkCommands.SYNC_DIFF, _handle_diff_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)

static var _logger := NetfoxLogger._for_netfox("NetworkSynchronizationServer")

signal on_input(snapshot: Snapshot)
signal on_state(snapshot: Snapshot)

func register_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.add(node, property)
	if node.is_multiplayer_authority():
		_rb_owned_state_properties.add(node, property)

func deregister_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.erase(node, property)
	_rb_owned_state_properties.erase(node, property)

func register_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.add(node, property)
	if node.is_multiplayer_authority():
		_rb_owned_input_properties.add(node, property)

func deregister_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.erase(node, property)
	_rb_owned_input_properties.erase(node, property)

func register_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.add(node, property)
	if node.is_multiplayer_authority():
		_sync_owned_state_properties.add(node, property)

func deregister_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.erase(node, property)
	_sync_owned_state_properties.erase(node, property)

func register_schema(node: Node, property: NodePath, serializer: NetworkSchemaSerializer) -> void:
	_schemas.add(node, property, serializer)

func deregister_schema(node: Node, property: NodePath) -> void:
	_schemas.erase(node, property)

func deregister_schema_for(node: Node) -> void:
	_schemas.erase_subject(node)

func register_visibility_filter(node: Node, filter: PeerVisibilityFilter) -> void:
	_visibility_filters[node] = filter

func deregister_visibility_filter(node: Node) -> void:
	_visibility_filters.erase(node)

func deregister(node: Node) -> void:
	_rb_state_properties.erase_subject(node)
	_rb_input_properties.erase_subject(node)
	_rb_owned_state_properties.erase_subject(node)
	_rb_owned_input_properties.erase_subject(node)
	_sync_state_properties.erase_subject(node)
	_visibility_filters.erase(node)

func is_node_visible_to(peer: int, node: Node) -> bool:
	# TODO: Cache visibilities
	var filter := _visibility_filters.get(node) as PeerVisibilityFilter
	if not filter:
		return true
	else:
		return filter.get_visibility_for(peer)

# TODO: Make this testable somehow, I beg of you
func synchronize_input(tick: int) -> void:
	# We don't own inputs, nothing to synchronize
	if _rb_owned_input_properties.is_empty():
		return

	var snapshots := [] as Array[Snapshot]
	var notified_peers := _Set.new()

	if not _rb_enable_input_broadcast:
		# If input broadcast is off, find which peers need to know our inputs
		# That is all peers who own state controlled by our input

		# Grab owned input objects
		for input_subject in _rb_owned_input_properties.get_subjects():
			# Grab state objects controlled by input
			var controlled_nodes := RollbackSimulationServer.get_controlled_by(input_subject)

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
		var snapshot := NetworkHistoryServer.get_rollback_input_snapshot(tick - offset)
		if not snapshot:
			break

		_logger.trace("Submitting input: %s", [snapshot])
		snapshots.append(snapshot)

	_logger.trace("Submitting input to peers: %s", [notified_peers])
	for peer in notified_peers:
		var data := _redundant_serializer.write_for(peer, snapshots, _rb_owned_input_properties)
		_cmd_input.send(data, peer)

# TODO: Make this testable somehow, I beg of you
func synchronize_state(tick: int) -> void:
	# We don't own state, nothing to synchronize
	if _rb_owned_state_properties.is_empty():
		return

	# Grab snapshot from NetworkHistoryServer
	var snapshot := NetworkHistoryServer.get_rollback_state_snapshot(tick)
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
	var reference_snapshot := NetworkHistoryServer.get_rollback_state_snapshot(tick - 1)
	if not reference_snapshot:
		is_full = true

	if is_full:
		# Send full states
		for peer in multiplayer.get_peers():
			var filter := func(subject): return is_node_visible_to(peer, subject)

			var data := _dense_serializer.write_for(peer, snapshot, _rb_owned_state_properties, filter)
			if data.is_empty():
				# Peer can't see anything, send nothing
				continue

			_cmd_full_state.send(data, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(snapshot.size())
	else:
		var diff := Snapshot.make_patch(reference_snapshot, snapshot)
		if diff.is_empty():
			# Nothing changed, don't send anything
			return

		# Send diff states
		for peer in multiplayer.get_peers():
			var filter := func(subject): return is_node_visible_to(peer, subject)

			var data := _sparse_serializer.write_for(peer, diff, _rb_owned_state_properties, filter)
			if data.is_empty():
				# Peer can't see any changes, send nothing
				continue

			_cmd_diff_state.send(data, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(diff.size())

func synchronize_sync_state(tick: int) -> void:
	# We don't own sync state, nothing to synchronize
	if _sync_owned_state_properties.is_empty():
		return

	# Grab snapshot from NetworkHistoryServer
	var snapshot := NetworkHistoryServer.get_synchronizer_state_snapshot(tick)
	if not snapshot:
		return

	# Figure out whether to send full- or diff state
	var is_full := _sync_full_scheduler.is_now()
	if not _sync_enable_diffs:
		is_full = true

	if is_full:
		# Send full states
		for peer in multiplayer.get_peers():
			var filter := func(subject): return is_node_visible_to(peer, subject)

			var data := _dense_serializer.write_for(peer, snapshot, _sync_owned_state_properties, filter)
			if data.is_empty():
				# Peer can't see anything, send nothing
				continue

			_cmd_full_sync.send(data, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(snapshot.size())
	else:
		var diff := Snapshot.make_patch(_last_sync_state_sent, snapshot)

		# Send diffs
		for peer in multiplayer.get_peers():
			var filter := func(subject): return is_node_visible_to(peer, subject)

			var data := _sparse_serializer.write_for(peer, diff, _sync_owned_state_properties, filter)
			if data.is_empty():
				# Peer can't see anything, send nothing
				continue

			_cmd_diff_sync.send(data, peer)

			NetworkPerformance.push_full_state_props(snapshot.size())
			NetworkPerformance.push_sent_state_props(diff.size())

	# Remember last sent state for diffing
	# NOTE: This is a shared instance, theoretically shouldn't screw things up
	_last_sync_state_sent = snapshot

func _handle_input(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshots := _redundant_serializer.read_from(sender, _rb_input_properties, buffer, true)
	_logger.trace("Received input snapshots: %s", [snapshots])

	for snapshot in snapshots:
		# TODO: Sanitize

		# TODO: Only merge inputs we don't have yet, so clients don't cheat by
		#       overriding their earlier choices. Only emit signal for snapshots
		#       that contain new input.
		var merged := NetworkHistoryServer.merge_rollback_input(snapshot)
		_logger.debug("Ingested input: %s", [snapshot])

		on_input.emit(snapshot)

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

	NetworkHistoryServer.merge_synchronizer_state(snapshot)
	_logger.trace("Ingested sync state: %s", [snapshot])

func _handle_diff_sync(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _sparse_serializer.read_from(sender, _sync_state_properties, buffer)

	NetworkHistoryServer.merge_synchronizer_state(snapshot)
	_logger.trace("Ingested sync diff: %s", [snapshot])

func _ingest_state(sender: int, snapshot: Snapshot) -> void:
	# TODO: Sanitize
#	_logger.debug("Received state snapshot: %s", [snapshot])

	var merged := NetworkHistoryServer.merge_rollback_state(snapshot)
	_logger.debug("Ingested state: %s", [snapshot])

	on_state.emit(snapshot)
