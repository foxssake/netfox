extends _BaseSnapshotSerializer
class_name _DenseSnapshotSerializer

static func _static_init():
	_logger = NetfoxLogger._for_netfox("DenseSnapshotSerializer")

func write_for(peer: int, snapshot: Snapshot, properties: _PropertyPool, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()

	var node_buffer := StreamPeerBuffer.new()

	# Write tick
	buffer.put_u32(snapshot.tick)
	# TODO: Include property config hash to detect mismatches

	# For each node
	for subject in properties.get_subjects():
		var node := subject as Node
		assert(node.is_multiplayer_authority(), "Trying to serialize state for non-owned node!")

		# Write identifier
		if _write_identifier(node, peer, buffer) != OK:
			continue

		# Write properties as-is
		# First into a buffer, so we can start with the state size
		node_buffer.clear()
		for property in properties.get_properties_of(node):
			# TODO: Subject-level auth tracking so we don't have to do this check for every property
			if not snapshot.is_auth(node, property): continue

			assert(snapshot.has_property(node, property), "Trying to serialize missing property %s on subject %s!" % [property, node])
			assert(snapshot.is_auth(node, property), "Trying to serialize non-auth state property!")

			var value := snapshot.get_property(node, property)
			_write_property(node, property, value, node_buffer)

		# Indicate state size for the node
		varuint.encode(node_buffer.data_array.size(), buffer)

		# Write node state
		buffer.put_data(node_buffer.data_array)

	return buffer.data_array

func read_from(peer: int, properties: _PropertyPool, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
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
			continue
		var node := identifier.get_subject() as Node

		# Read properties
		for property in properties.get_properties_of(node):
			# TODO: Test if less bytes remain than an entire property ( e.g. 2 bytes )
			if node_buffer.get_available_bytes() == 0: break

			var value := _read_property(node, property, node_buffer)
			snapshot.set_property(node, property, value, is_auth)

	return snapshot
