extends _BaseSnapshotSerializer
class_name _SparseSnapshotSerializer

static func _static_init():
	_logger = NetfoxLogger._for_netfox("SparseSnapshotSerializer")

func write_for(peer: int, snapshot: Snapshot, properties: _PropertyPool, buffer: StreamPeerBuffer = null) -> PackedByteArray:
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
		if _write_identifier(node, peer, buffer) != OK:
			continue

		node_buffer.clear()

		var node_props := properties.get_properties_of(node)
		var changed_bits := _Bitset.new(properties.size())
		
		for i in node_props.size():
			var property := node_props[i]
			if not snapshot.has_property(node, property):
				continue

			assert(snapshot.is_auth(node, property), "Trying to serialize non-auth state property!")

			changed_bits.set_bit(i)
			var value := snapshot.get_property(node, property)
			_write_property(node, property, value, node_buffer)
		
		varuint.encode(node_buffer.data_array.size(), buffer)	# Node props len
		varbits.encode(changed_bits, buffer)					# Changed prop bits
		buffer.put_data(node_buffer.data_array)					# Changed props
	
	return buffer.data_array

func read_from(peer: int, properties: _PropertyPool, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
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
		var node_props := properties.get_properties_of(node)
		for idx in changed_bits.get_set_indices():
			var property := node_props[idx]
			var value := _read_property(node, property, node_buffer)
			snapshot.set_property(node, property, value, is_auth)
	return snapshot
