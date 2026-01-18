extends RefCounted
class_name DenseSnapshotSerializer

#func serialize_for(peer: int, snapshot: Snapshot, buffer: StreamPeerBuffer = null) -> PackedByteArray:
#	if buffer == null:
#		buffer = StreamPeerBuffer.new()
#
#	var netref := NetworkSchemas._netref()
#	var varuint := NetworkSchemas.varuint()
#
#	var node_buffer := StreamPeerBuffer.new()
#
#	# Write tick
#	buffer.put_u32(snapshot.tick)
#	# TODO: Include property config hash to detect mismatches
#
#	# For each node
#	for node in snapshot.nodes():
#		assert(node.is_multiplayer_authority(), "Trying to serialize state for non-owned node!")
#
#		# Write identifier
#		var identifier := NetworkIdentityServer.get_identifier_of(node)
#		if not identifier:
#			_logger.error("Can't synchronize node %s, identifier missing!", [node])
#			continue
#		var idref := identifier.reference_for(peer)
#		netref.encode(idref, buffer)
#
#		# Write properties as-is
#		# First into a buffer, so we can start with the state size
#		node_buffer.clear()
#		for property in get_properties_of(node):
#			assert(snapshot.is_auth(node, property), "Trying to serialize non-auth state property!")
#			var value := snapshot.get_property(node, property)
#			_serialize_property(node, property, value, node_buffer)
#
#		# Indicate state size for the node
#		varuint.encode(node_buffer.data_array.size(), buffer)
#
#		# Write node state
#		buffer.put_data(node_buffer.data_array)
#
#	return buffer.data_array
#
#func deserialize_of(peer: int, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
#	var netref := NetworkSchemas._netref()
#	var varuint := NetworkSchemas.varuint()
#	var node_buffer := StreamPeerBuffer.new()
#
#	# Read tick
#	var tick := buffer.get_u32()
#	var snapshot := Snapshot.new(tick)
#	# TODO: Include property config hash to detect mismatches
#
#	while buffer.get_available_bytes() > 0:
#		# Read identity reference, data size, and data
#		# TODO: Configurable upper limit on how much netfox is allowed to read here?
#		var idref := netref.decode(buffer) as _NetworkIdentityReference
#		var node_data_size := varuint.decode(buffer) as int
#		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]
#
#		# Resolve to identifier
#		var identifier := NetworkIdentityServer.resolve_reference(peer, idref)
#		if not identifier:
#			# TODO: Handle unknown IDs gracefully
#			# TODO: Test that unknown nodes are INDEED SKIPPED
#			_logger.warning("Received unknown identity reference %s, skipping data", [idref])
#			break
#		var node := identifier.get_subject() as Node
#
#		# Read properties
#		for property in get_properties_of(node):
#			# TODO: Test if less bytes remain than an entire property ( e.g. 2 bytes )
#			if node_buffer.get_available_bytes() == 0: break
#
#			var value := _deserialize_property(node, property, node_buffer)
#			snapshot.set_property(node, property, value, is_auth)
#
#	return snapshot
