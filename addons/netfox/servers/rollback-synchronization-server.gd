extends Node
class_name _RollbackSynchronizationServer

var _input_properties: Array = []
var _state_properties: Array = []
var _sync_state_properties: Array = [] as Array[Array]

var _visibility_filters := {} # Node to PeerVisibilityFilter

var _rb_enable_input_broadcast := false	# TODO: Config
var _rb_enable_diffs := true			# TODO: Config
var _rb_full_interval := 24				# TODO: Config
var _rb_full_next := -1

var _last_sync_state_sent := Snapshot.new(0)
var _sync_enable_diffs := true		# TODO: Config
var _sync_full_interval := 24		# TODO: Config
var _sync_full_next := -1

var _schemas := {} # RecordedProperty key to NetworkSchemaSerializer
var _fallback_schema := NetworkSchemas.variant()

var _input_redundancy := 3			# TODO: Config

@onready var _cmd_full_state := NetworkCommandServer.register_command_at(_NetworkCommands.FULL_STATE, _handle_full_state, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
@onready var _cmd_diff_state := NetworkCommandServer.register_command_at(_NetworkCommands.DIFF_STATE, _handle_diff_state, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
@onready var _cmd_input := NetworkCommandServer.register_command_at(_NetworkCommands.INPUT, _handle_input, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)

@onready var _cmd_full_sync := NetworkCommandServer.register_command_at(_NetworkCommands.FULL_SYNC, _handle_full_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
@onready var _cmd_diff_sync := NetworkCommandServer.register_command_at(_NetworkCommands.DIFF_SYNC, _handle_diff_sync, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)

static var _logger := NetfoxLogger._for_netfox("RollbackSynchronizationServer")

signal on_input(snapshot: Snapshot)
signal on_state(snapshot: Snapshot)

func register_property(node: Node, property: NodePath, pool: Array) -> void:
	var entry := RecordedProperty.key_of(node, property)

	# TODO: Accelerate this check, maybe with _Set
	if not pool.has(entry):
		pool.append(entry)

func deregister_property(node: Node, property: NodePath, pool: Array) -> void:
	pool.erase([node, property])

func register_state(node: Node, property: NodePath) -> void:
	register_property(node, property, _state_properties)

func deregister_state(node: Node, property: NodePath) -> void:
	deregister_property(node, property, _state_properties)

func register_input(node: Node, property: NodePath) -> void:
	register_property(node, property, _input_properties)

func deregister_input(node: Node, property: NodePath) -> void:
	deregister_property(node, property, _input_properties)

func register_sync_state(node: Node, property: NodePath) -> void:
	register_property(node, property, _sync_state_properties)

func deregister_sync_state(node: Node, property: NodePath) -> void:
	deregister_property(node, property, _sync_state_properties)

func register_schema(node: Node, property: NodePath, serializer: NetworkSchemaSerializer) -> void:
	var key := RecordedProperty.key_of(node, property)
	_schemas[key] = serializer

func deregister_schema(node: Node, property: NodePath) -> void:
	var key := RecordedProperty.key_of(node, property)
	_schemas.erase(key)

func register_visibility_filter(node: Node, filter: PeerVisibilityFilter) -> void:
	_visibility_filters[node] = filter

func deregister_visibility_filter(node: Node) -> void:
	_visibility_filters.erase(node)

func is_property_visible_to(peer: int, node: Node, property: NodePath) -> bool:
	# TODO: Cache visibilities
	var filter := _visibility_filters.get(node) as PeerVisibilityFilter
	if not filter:
		return true
	else:
		return filter.get_visibility_for(peer)

# TODO: Optimize
func get_properties_of(node: Node) -> Array[NodePath]:
	var result := [] as Array[NodePath]
	
	# TODO: Split method? Or somehow avoid this merge
	for property in _state_properties + _input_properties + _sync_state_properties:
		var prop_node := RecordedProperty.get_node(property)
		var prop_path := RecordedProperty.get_property(property)

		if node == prop_node:
			result.append(prop_path)
	
	return result

# TODO: Make this testable somehow, I beg of you
func synchronize_input(tick: int) -> void:
	var snapshots := [] as Array[Snapshot]
	var notified_peers := _Set.new()

	if not _rb_enable_input_broadcast:
		# Grab owned input objects
		var input_objects := _Set.new()
		for prop in _input_properties:
			var node := RecordedProperty.get_node(prop)
			input_objects.add(node)

		# for each input object
		for input_object in input_objects:
			# Grab state objects controlled by input
			var controlled_nodes := RollbackSimulationServer.get_controlled_by(input_object)

			# Notify peers owning nodes about the input
			for node in controlled_nodes:
				notified_peers.add(node.get_multiplayer_authority())
	else:
		for peer in multiplayer.get_peers():
			notified_peers.add(peer)

	notified_peers.erase(multiplayer.get_unique_id())
	# Only send input to peers in set

	for offset in _input_redundancy:
		# Grab snapshot from RollbackHistoryServer
		var snapshot := RollbackHistoryServer.get_rollback_input_snapshot(tick - offset)
		if not snapshot:
			break

		# Filter to input properties
		# TODO: Optimize, avoid making two copies
		var input_snapshot := snapshot.filtered_to_owned()

		# Transmit
		_logger.trace("Submitting input: %s", [input_snapshot])
		snapshots.append(input_snapshot)

	_logger.trace("Submitting input to peers: %s", [notified_peers])
	for peer in notified_peers:
		_cmd_input.send(_serialize_input_for(peer, snapshots), peer)

# TODO: Make this testable somehow, I beg of you
func synchronize_state(tick: int) -> void:
	# Grab snapshot from RollbackHistoryServer
	var snapshot := RollbackHistoryServer.get_rollback_state_snapshot(tick)
	if not snapshot:
		# No data for tick
		return

	# Filter to state properties
	var state_snapshot := snapshot.filtered_to_auth().filtered_to_owned()
	
	# TODO: Early exit if we don't have auth state props
	if state_snapshot.is_empty():
		# Nothing to send
		return
	
	# Figure out whether to send full- or diff state
	var is_diff := false
	if _rb_enable_diffs:
		if _rb_full_interval <= 0:
			is_diff = true
		elif _rb_full_next < 0:
			is_diff = true

	# Check if we have history to diff to
	var reference_snapshot := RollbackHistoryServer.get_rollback_state_snapshot(tick - 1)
	if not reference_snapshot:
		is_diff = false

	if is_diff:
		_rb_full_next -= 1
		reference_snapshot = reference_snapshot.filtered_to_auth().filtered_to_owned()
		var diff := Snapshot.make_patch(reference_snapshot, state_snapshot)
		if diff.is_empty():
			# Nothing changed, don't send anything
			return

		# Send diff states
		for peer in multiplayer.get_peers():
			var peer_diff := diff.filtered(func(node, prop): return is_property_visible_to(peer, node, prop))
			if peer_diff.is_empty():
				# Peer can't see any changes, send nothing
				continue

			_cmd_diff_state.send(_serialize_diff_state_for(peer, peer_diff), peer)

			NetworkPerformance.push_full_state(state_snapshot.data) # TODO: Ugh...
			NetworkPerformance.push_sent_state(diff.data) # TODO: Ugh...
	else:
		_rb_full_next = _rb_full_interval

		# Send full states
		for peer in multiplayer.get_peers():
			var peer_snapshot := state_snapshot.filtered(func(node, prop): return is_property_visible_to(peer, node, prop))
			if peer_snapshot.is_empty():
				# Peer can't see anything, send nothing
				continue

			_cmd_full_state.send(_serialize_full_state_for(peer, peer_snapshot), peer)
			_logger.trace("Sent full state to #%d: %s", [peer, peer_snapshot])

			NetworkPerformance.push_full_state(peer_snapshot.data) # TODO: Ugh...
			NetworkPerformance.push_sent_state(peer_snapshot.data) # TODO: Ugh...
			_logger.debug("Pushed full state metrics: %d sent, %d full", [peer_snapshot.data.size(), peer_snapshot.data.size()])

func synchronize_sync_state(tick: int) -> void:
	# TODO: Reduce copy-paste
	# Grab snapshot from RollbackHistoryServer
	var snapshot := RollbackHistoryServer.get_synchronizer_state_snapshot(tick)
	if not snapshot:
		return

	# Filter to state properties
	var state_snapshot := snapshot.filtered_to_auth().filtered_to_owned()

	# Figure out whether to send full- or diff state
	var is_diff := false
	if _sync_enable_diffs:
		if _sync_full_interval <= 0:
			is_diff = true
		elif _sync_full_next < 0:
			is_diff = true

	if not is_diff:
		_sync_full_next = _sync_full_interval

		# Send full states
		for peer in multiplayer.get_peers():
			var peer_snapshot := state_snapshot.filtered(func(node, prop): return is_property_visible_to(peer, node, prop))

			if peer_snapshot.is_empty():
				# Peer can't see anything, send nothing
				continue

			_cmd_full_sync.send(_serialize_full_state_for(peer, peer_snapshot), peer)
			
			NetworkPerformance.push_full_state(peer_snapshot.data) # TODO: Ugh...
			NetworkPerformance.push_sent_state(peer_snapshot.data) # TODO: Ugh...
	else:
		_sync_full_next -= 1
		var diff := Snapshot.make_patch(_last_sync_state_sent, state_snapshot)

		# Send diffs
		for peer in multiplayer.get_peers():
			var peer_snapshot := diff.filtered(func(node, prop): return is_property_visible_to(peer, node, prop))

			if peer_snapshot.is_empty():
				# Nothing changed, don't send anything
				continue

			_cmd_diff_sync.send(_serialize_diff_state_for(peer, peer_snapshot), peer)
			
			NetworkPerformance.push_full_state(state_snapshot.data) # TODO: Ugh...
			NetworkPerformance.push_sent_state(peer_snapshot.data) # TODO: Ugh...

	# Remember last sent state for diffing
	_last_sync_state_sent = state_snapshot

func _serialize_full_state_for(peer: int, snapshot: Snapshot, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	
	var node_buffer := StreamPeerBuffer.new()
	
	# Write tick
	buffer.put_u32(snapshot.tick)
	# TODO: Include property config hash to detect mismatches
	
	# For each node
	for node in snapshot.nodes():
		assert(node.is_multiplayer_authority(), "Trying to serialize state for non-owned node!")

		# Write identifier
		var identifier := NetworkIdentityServer.get_identifier_of(node)
		if not identifier:
			_logger.error("Can't synchronize node %s, identifier missing!", [node])
			continue
		var idref := identifier.reference_for(peer)
		netref.encode(idref, buffer)
		
		# Write properties as-is
		# First into a buffer, so we can start with the state size
		node_buffer.clear()
		for property in get_properties_of(node):
			assert(snapshot.is_auth(node, property), "Trying to serialize non-auth state property!")
			var value := snapshot.get_property(node, property)
			_serialize_property(node, property, value, node_buffer)
		
		# Indicate state size for the node
		varuint.encode(node_buffer.data_array.size(), buffer)
		
		# Write node state
		buffer.put_data(node_buffer.data_array)

	return buffer.data_array

func _deserialize_full_state_of(peer: int, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var node_buffer := StreamPeerBuffer.new()
	
	# Read tick
	var tick := buffer.get_u32()
	var snapshot := Snapshot.new(tick)
	# TODO: Include property config hash to detect mismatches
	
	while buffer.get_available_bytes() > 0:
		# Read identity reference, data size, and data
		# TODO: Configurable upper limit on how much netfox is allowed to read here?
		var idref := netref.decode(buffer) as _NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]
		
		# Resolve to identifier
		var identifier := NetworkIdentityServer.resolve_reference(peer, idref)
		if not identifier:
			# TODO: Handle unknown IDs gracefully
			# TODO: Test that unknown nodes are INDEED SKIPPED
			_logger.warning("Received unknown identity reference %s, skipping data", [idref])
			break
		var node := identifier.get_subject() as Node
		
		# Read properties
		for property in get_properties_of(node):
			# TODO: Test if less bytes remain than an entire property ( e.g. 2 bytes )
			if node_buffer.get_available_bytes() == 0: break

			var value := _deserialize_property(node, property, node_buffer)
			snapshot.set_property(node, property, value, is_auth)
	
	return snapshot

func _serialize_diff_state_for(peer: int, snapshot: Snapshot, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var varbits := NetworkSchemas._varbits()
	
	var node_buffer := StreamPeerBuffer.new()
	
	# Write ticks
	buffer.put_u32(snapshot.tick)
	# TODO: Include property config hash to detect mismatches

	# For each node
	for node in snapshot.nodes():
		assert(node.is_multiplayer_authority(), "Trying to serialize state for non-owned node!")

		# Write identifier
		var identifier := NetworkIdentityServer.get_identifier_of(node)
		if not identifier:
			_logger.error("Can't synchronize node %s, identifier missing!", [node])
			continue
		var idref := identifier.reference_for(peer)
		netref.encode(idref, buffer)

		node_buffer.clear()

		var properties := get_properties_of(node)
		var changed_bits := _Bitset.new(properties.size())
		
		for i in properties.size():
			var property := properties[i]
			if not snapshot.has_property(node, property):
				continue

			assert(snapshot.is_auth(node, property), "Trying to serialize non-auth state property!")

			changed_bits.set_bit(i)
			var value := snapshot.get_property(node, property)
			_serialize_property(node, property, value, node_buffer)
		
		varuint.encode(node_buffer.data_array.size(), buffer)	# Node props len
		varbits.encode(changed_bits, buffer)					# Changed prop bits
		buffer.put_data(node_buffer.data_array)					# Changed props
	
	return buffer.data_array

func _deserialize_diff_state_of(peer: int, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var varbits := NetworkSchemas._varbits()
	var node_buffer := StreamPeerBuffer.new()
	
	# Grab ticks
	var tick := buffer.get_u32()
	# TODO: Include property config hash to detect mismatches
	
	var snapshot := Snapshot.new(tick)
	
	while buffer.get_available_bytes() > 0:
		# Read header, including identity reference
		# TODO: Configurable upper limit on how much netfox is allowed to read here?
		var idref := netref.decode(buffer) as _NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		var changed_bits := varbits.decode(buffer) as _Bitset
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]
		
		# Resolve to identifier
		var identifier := NetworkIdentityServer.resolve_reference(peer, idref)
		if not identifier:
			# TODO: Handle unknown IDs gracefully
			# TODO: Test that unknown nodes are INDEED SKIPPED
			_logger.warning("Received unknown identity reference %s, skipping data", [idref])
			break
		var node := identifier.get_subject() as Node
		
		# Read changed properties
		var properties := get_properties_of(node)
		for idx in changed_bits.get_set_indices():
			var property := properties[idx]
			var value := _deserialize_property(node, property, node_buffer)
			snapshot.set_property(node, property, value, is_auth)
	return snapshot

func _serialize_input_for(peer: int, snapshots: Array[Snapshot], buffer: StreamPeerBuffer = null) -> PackedByteArray:
	var varuint := NetworkSchemas.varuint()
	
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	for snapshot in snapshots:
		# TODO: Rename method
		var serialized := _serialize_full_state_for(peer, snapshot)
		
		# Write size and snapshot
		varuint.encode(serialized.size(), buffer)
		buffer.put_data(serialized)

	return buffer.data_array

func _deserialize_input_of(peer: int, buffer: StreamPeerBuffer, is_auth: bool = true) -> Array[Snapshot]:
	var varuint := NetworkSchemas.varuint()
	
	var snapshots := [] as Array[Snapshot]
	while buffer.get_available_bytes() > 0:
		var snapshot_size := varuint.decode(buffer)
		var snapshot_buffer := StreamPeerBuffer.new()
		snapshot_buffer.data_array = buffer.get_partial_data(snapshot_size)[1]
		
		snapshots.append(_deserialize_full_state_of(peer, snapshot_buffer, is_auth))
	return snapshots

func _serialize_property(node: Node, property: NodePath, value: Variant, buffer: StreamPeerBuffer) -> void:
	var serializer := _schemas.get(RecordedProperty.key_of(node, property), _fallback_schema) as NetworkSchemaSerializer
	serializer.encode(value, buffer)

func _deserialize_property(node: Node, property: NodePath, buffer: StreamPeerBuffer) -> Variant:
	var serializer := _schemas.get(RecordedProperty.key_of(node, property), _fallback_schema) as NetworkSchemaSerializer
	return serializer.decode(buffer)

func _handle_input(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshots := _deserialize_input_of(sender, buffer)
	_logger.trace("Received input snapshots: %s", [snapshots])

	for snapshot in snapshots:
		# TODO: Sanitize

		# TODO: Only merge inputs we don't have yet, so clients don't cheat by
		#       overriding their earlier choices. Only emit signal for snapshots
		#       that contain new input.
		var merged := RollbackHistoryServer.merge_rollback_input(snapshot)
		_logger.trace("Ingested input: %s", [snapshot])

		on_input.emit(snapshot)

func _handle_full_state(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _deserialize_full_state_of(sender, buffer)
	
	_ingest_state(sender, snapshot)

func _handle_diff_state(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var diff := _deserialize_diff_state_of(sender, buffer)
	_logger.trace("Received diff state for @%d", [diff.tick])
	
	# TODO: Using `snapshot` doesn't work
	_ingest_state(sender, diff)

func _handle_full_sync(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _deserialize_full_state_of(sender, buffer)

	# TODO: Reduce copy-paste
	RollbackHistoryServer.merge_synchronizer_state(snapshot)
	_logger.trace("Ingested sync state: %s", [snapshot])

func _handle_diff_sync(sender: int, data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var snapshot := _deserialize_diff_state_of(sender, buffer)

	# TODO: Reduce copy-paste
	RollbackHistoryServer.merge_synchronizer_state(snapshot)
	_logger.trace("Ingested sync state diff: %s", [snapshot])

func _ingest_state(sender: int, snapshot: Snapshot) -> void:
	# TODO: Sanitize
#	_logger.debug("Received state snapshot: %s", [snapshot])

	var stored_snapshot := RollbackHistoryServer.get_rollback_state_snapshot(snapshot.tick)
	if stored_snapshot:
		var diff := Snapshot.make_patch(stored_snapshot, snapshot, snapshot.tick, false)
		if not diff.is_empty():
			_logger.trace("Reconciled state diff: %s", [diff])
	
	var merged := RollbackHistoryServer.merge_rollback_state(snapshot)
	_logger.trace("Ingested state: %s", [snapshot])

	on_state.emit(snapshot)
