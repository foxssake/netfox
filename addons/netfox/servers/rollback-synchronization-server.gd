extends Node
class_name _RollbackSynchronizationServer

# TODO: Support various encoders
# TODO: Honor visibility filters

var _input_properties: Array = []
var _state_properties: Array = []

var _full_state_interval := 0		# TODO: Config
var _state_ack_interval := 2		# TODO: Config
var _ackd_tick := {} # peer id to ack'd tick

var _schemas := {} # RecordedProperty key to NetworkSchemaSerializer
var _fallback_schema := NetworkSchemas.variant()

var _input_redundancy := 3			# TODO: Config

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

func register_schema(node: Node, property: NodePath, serializer: NetworkSchemaSerializer) -> void:
	var key := RecordedProperty.key_of(node, property)
	_schemas[key] = serializer

func deregister_schema(node: Node, property: NodePath) -> void:
	var key := RecordedProperty.key_of(node, property)
	_schemas.erase(key)

# TODO: Optimize
func get_properties_of(node: Node) -> Array[NodePath]:
	var result := [] as Array[NodePath]
	
	for property in _state_properties + _input_properties:
		var prop_node := RecordedProperty.get_node(property)
		var prop_path := RecordedProperty.get_property(property)
		
		if node == prop_node:
			result.append(prop_path)
	
	return result

# TODO: Make this testable somehow, I beg of you
func synchronize_input(tick: int) -> void:
	var snapshots := [] as Array[Snapshot]

	for offset in _input_redundancy:
		# Grab snapshot from RollbackHistoryServer
		var snapshot := RollbackHistoryServer.get_snapshot(tick + offset)
		if not snapshot:
			break

		# Filter to input properties
		# TODO: Optimize, avoid making two copies
		var input_snapshot := snapshot.filtered_to_properties(_input_properties).filtered_to_owned()

		# Transmit
		# _logger.debug("Submitting input: %s", [input_snapshot])
		snapshots.append(input_snapshot)

	# TODO: Option to not broadcast input
	for peer in multiplayer.get_peers():
		_submit_input.rpc_id(peer, _serialize_input_for(peer, snapshots))

# TODO: Make this testable somehow, I beg of you
func synchronize_state(tick: int) -> void:
	# Grab snapshot from RollbackHistoryServer
	var snapshot := RollbackHistoryServer.get_snapshot(tick)
	if not snapshot:
		return

	# Filter to state properties
	var state_snapshot := snapshot.filtered_to_properties(_state_properties)
	
	# Figure out whether to send full- or diff state
	var is_diff := true # false
	if _full_state_interval <= 0:
		is_diff = true
	elif _full_state_interval >= 1 and (tick % _full_state_interval) != 0:
		# TODO: Something better than modulo logic? --^
		is_diff = true

	# Transmit
	if is_diff:
		for peer in multiplayer.get_peers():
			if not _ackd_tick.has(peer):
				# We don't know any state the peer knows, send full state
				_submit_full_state.rpc_id(peer, _serialize_full_state_for(peer, state_snapshot))
				_logger.info("Sent full state for @%d to #%d", [tick, peer])
				continue

			var reference_tick := _ackd_tick[peer] as int
			var reference_snapshot := RollbackHistoryServer.get_snapshot(reference_tick)
			
			if not reference_snapshot:
				# Reference snapshot not in history, send full state
				_logger.warning("Tick @%d not present in history, can't use it as reference for peer #%d ( ack: %s )", [reference_tick, peer, _ackd_tick])
				_submit_full_state.rpc_id(peer, _serialize_full_state_for(peer, state_snapshot))
				_logger.info("Sent full state for @%d to #%d", [tick, peer])
				continue

			# TODO: Optimize, don't create two snapshots
			reference_snapshot = reference_snapshot.filtered_to_auth().filtered_to_properties(_state_properties)
			
			_logger.debug("Sending diff state for @%d to #@%d, relative to @%d", [tick, peer, reference_tick])
			
			var diff_snapshot := Snapshot.make_patch(reference_snapshot, state_snapshot, tick)
			_submit_diff_state.rpc_id(peer, _serialize_diff_state_of(peer, diff_snapshot, reference_tick))
#			_submit_state.rpc_id(peer, _serialize_snapshot(state_snapshot))
#			_logger.info("Sent diff state for @%d <- @%d to #%d", [tick, reference_tick, peer])
	else:
		for peer in multiplayer.get_peers():
			_submit_full_state.rpc_id(peer, _serialize_full_state_for(peer, state_snapshot))

func _serialize_full_state_for(peer: int, snapshot: Snapshot, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	var netref := NetworkSchemas.netref()
	var varuint := NetworkSchemas.varuint()
	
	var node_buffer := StreamPeerBuffer.new()
	
	# Write tick
	buffer.put_u32(snapshot.tick)
	# TODO: Include property config hash to detect mismatches
	
	# For each node
	for node in snapshot.nodes():
		if not node.is_multiplayer_authority():
			continue

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
			var value := snapshot.get_property(node, property)
			_serialize_property(node, property, value, node_buffer)
		
		# Indicate state size for the node
		varuint.encode(node_buffer.data_array.size(), buffer)
		
		# Write node state
		buffer.put_data(node_buffer.data_array)

	return buffer.data_array

func _deserialize_full_state_of(peer: int, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
	var netref := NetworkSchemas.netref()
	var varuint := NetworkSchemas.varuint()
	var node_buffer := StreamPeerBuffer.new()
	
	# Read tick
	var tick := buffer.get_u32()
	var snapshot := Snapshot.new(tick)
	# TODO: Include property config hash to detect mismatches
	
	while buffer.get_available_bytes() > 0:
		# Read identity reference, data size, and data
		# TODO: Configurable upper limit on how much netfox is allowed to read here?
		var idref := netref.decode(buffer) as NetworkIdentityServer.NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]
		
		# Resolve to identifier
		var identifier := NetworkIdentityServer.resolve_reference(peer, idref)
		if not identifier:
			# TODO: Handle unknown IDs gracefully
			# TODO: Test that unknown nodes are INDEED SKIPPED
			_logger.error("Received unknown identity reference %s, skipping data", [idref])
			break
		var node := identifier.get_subject() as Node
		
		# Read properties
		for property in get_properties_of(node):
			# TODO: Test if less bytes remain than an entire property ( e.g. 2 bytes )
			if node_buffer.get_available_bytes() == 0: break

			var value := _deserialize_property(node, property, node_buffer)
			snapshot.set_property(node, property, value, is_auth)
	
	return snapshot

func _serialize_diff_state_of(peer: int, snapshot: Snapshot, reference_tick: int, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	var netref := NetworkSchemas.netref()
	var varuint := NetworkSchemas.varuint()
	var varbits := NetworkSchemas._varbits()
	
	var node_buffer := StreamPeerBuffer.new()
	
	# Write ticks
	buffer.put_u32(snapshot.tick)
	buffer.put_u32(reference_tick)
	# TODO: Include property config hash to detect mismatches

	# For each node
	for node in snapshot.nodes():
		if not node.is_multiplayer_authority():
			continue

		# Write identifier
		var identifier := NetworkIdentityServer.get_identifier_of(node)
		if not identifier:
			_logger.error("Can't synchronize node %s, identifier missing!", [node])
			continue
		var idref := identifier.reference_for(peer)
		netref.encode(idref, buffer)

		node_buffer.clear()
		
		# TODO: Create bitset of changed properties
		# TODO: Write changed properties into `node_buffer`
		var properties := get_properties_of(node)
		var changed_bits := _Bitset.new(properties.size())
		
		for i in properties.size():
			var property := properties[i]
			if not snapshot.has_property(node, property):
				continue

			changed_bits.set_bit(i)
			var value := snapshot.get_property(node, property)
			_serialize_property(node, property, value, node_buffer)
		
		varuint.encode(node_buffer.data_array.size(), buffer)	# Node props len
		varbits.encode(changed_bits, buffer)					# Changed prop bits
		buffer.put_data(node_buffer.data_array)					# Changed props
	
	return buffer.data_array

func _deserialize_diff_state_of(peer: int, buffer: StreamPeerBuffer, is_auth: bool = true) -> DiffSnapshot:
	var netref := NetworkSchemas.netref()
	var varuint := NetworkSchemas.varuint()
	var varbits := NetworkSchemas._varbits()
	var node_buffer := StreamPeerBuffer.new()
	
	# Grab ticks
	var tick := buffer.get_u32()
	var reference_tick := buffer.get_u32()
	# TODO: Include property config hash to detect mismatches
	
	var snapshot := Snapshot.new(tick)
	
	while buffer.get_available_bytes() > 0:
		# Read header, including identity reference
		# TODO: Configurable upper limit on how much netfox is allowed to read here?
		var idref := netref.decode(buffer) as NetworkIdentityServer.NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		var changed_bits := varbits.decode(buffer) as _Bitset
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]
		
		# Resolve to identifier
		var identifier := NetworkIdentityServer.resolve_reference(peer, idref)
		if not identifier:
			# TODO: Handle unknown IDs gracefully
			# TODO: Test that unknown nodes are INDEED SKIPPED
			_logger.error("Received unknown identity reference %s, skipping data", [idref])
			break
		var node := identifier.get_subject() as Node
		
		# Read changed properties
		var properties := get_properties_of(node)
		for idx in changed_bits.get_set_indices():
			var property := properties[idx]
			var value := _deserialize_property(node, property, node_buffer)
			snapshot.set_property(node, property, value, is_auth)
	return DiffSnapshot.new(snapshot, reference_tick)

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

@rpc("any_peer", "call_remote", "reliable")
func _submit_input(data: PackedByteArray):
	var sender := multiplayer.get_remote_sender_id()
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	for snapshot in _deserialize_input_of(sender, buffer):
	#	_logger.debug("Received input snapshot: %s", [snapshot])

		# TODO: Sanitize

		var merged := RollbackHistoryServer.merge_snapshot(snapshot)
	#	_logger.debug("Merged input; %s", [merged])

		on_input.emit(snapshot)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_full_state(data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var sender := multiplayer.get_remote_sender_id()
	var snapshot := _deserialize_full_state_of(sender, buffer)
	
	_ingest_state(sender, snapshot)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_diff_state(data: PackedByteArray):
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var sender := multiplayer.get_remote_sender_id()
	var diff := _deserialize_diff_state_of(sender, buffer)
	var reference_tick := diff.reference_tick
	var reference_snapshot := RollbackHistoryServer.get_snapshot(reference_tick)
	_logger.debug("Received diff state for @%d, relative to @%d", [diff.snapshot.tick, reference_tick])
	if not reference_snapshot:
		_logger.warning("Reference tick %d missing for #%d, ignoring", [reference_tick, sender])
		return

	var snapshot := reference_snapshot.duplicate()
	snapshot.merge(diff.snapshot)
	snapshot.tick = diff.snapshot.tick
	
	# TODO: Using `snapshot` doesn't work
	_ingest_state(sender, diff.snapshot)

func _ingest_state(sender: int, snapshot: Snapshot) -> void:
	# TODO: Sanitize
#	_logger.debug("Received state snapshot: %s", [snapshot])

	var merged := RollbackHistoryServer.merge_snapshot(snapshot)
#	_logger.debug("Merged state; %s", [merged])

	if _state_ack_interval >= 1 and (snapshot.tick % _state_ack_interval) == 0:
		_logger.debug("ACK'ing state @%d from #%d", [snapshot.tick, sender])
		_ack_state.rpc_id(sender, snapshot.tick)

	on_state.emit(snapshot)

@rpc("any_peer", "call_remote", "unreliable")
func _ack_state(tick: int):
	var sender := multiplayer.get_remote_sender_id()
	_ackd_tick[sender] = maxi(tick, _ackd_tick.get(sender, tick))
	_logger.debug("Received ACK for state @%d from #%d, new is %d", [tick, sender, _ackd_tick[sender]])

class DiffSnapshot:
	var snapshot: Snapshot
	var reference_tick: int
	
	func _init(p_snapshot: Snapshot, p_reference_tick: int):
		snapshot = p_snapshot
		reference_tick = p_reference_tick
