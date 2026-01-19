extends _BaseSnapshotSerializer
class_name _DenseSnapshotSerializer

static func _static_init():
	_logger = NetfoxLogger._for_netfox("DenseSnapshotSerializer")

func write_for(peer: int, snapshot: Snapshot, properties: _PropertyPool, filter: Callable = _default_filter, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	if buffer == null:
		buffer = StreamPeerBuffer.new()

	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()

	var node_buffer := StreamPeerBuffer.new()

	var has_data := false

	# Write tick
	buffer.put_u32(snapshot.tick)

	# For each node
	for subject in properties.get_subjects():
		if not filter.call(subject): continue
		if not snapshot.is_auth(subject): continue

		var node := subject as Node
		assert(node.is_multiplayer_authority(), "Trying to serialize state for non-owned node!")
		assert(snapshot.is_auth(node), "Trying to serialize non-auth state node!")

		# Write identifier
		if _write_identifier(node, peer, buffer) != OK:
			continue

		# Write properties as-is
		# First into a buffer, so we can start with the state size
		node_buffer.clear()
		for property in properties.get_properties_of(node):
			assert(snapshot.has_property(node, property), "Trying to serialize missing property %s on subject %s!" % [property, node])

			var value := snapshot.get_property(node, property)
			_write_property(node, property, value, node_buffer)

		# Indicate state size for the node
		varuint.encode(node_buffer.data_array.size(), buffer)

		# Write node state
		buffer.put_data(node_buffer.data_array)

		has_data = true

	if has_data:
		return buffer.data_array
	else:
		return PackedByteArray()

func read_from(peer: int, properties: _PropertyPool, buffer: StreamPeerBuffer, is_auth: bool = true) -> Snapshot:
	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var node_buffer := StreamPeerBuffer.new()

	# Read tick
	var tick := buffer.get_u32()
	var snapshot := Snapshot.new(tick)

	while buffer.get_available_bytes() > 0:
		# Read identity reference, data size, and data
		var idref := netref.decode(buffer) as _NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]

		# Resolve to identifier
		var identifier := _get_identity_server().resolve_reference(peer, idref)
		if not identifier:
			# TODO(#???): Handle unknown IDs gracefully
			_logger.warning("Received unknown identity reference %s, skipping data", [idref])
			continue
		var node := identifier.get_subject() as Node

		# Read properties
		for property in properties.get_properties_of(node):
			if node_buffer.get_available_bytes() == 0: break

			var value := _read_property(node, property, node_buffer)
			snapshot.set_property(node, property, value)
		snapshot.set_auth(node, is_auth)

	return snapshot
