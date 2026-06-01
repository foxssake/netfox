extends _BaseSnapshotSerializer
class_name _DenseSnapshotSerializer

static func _static_init():
	_logger = NetfoxLogger._for_netfox("DenseSnapshotSerializer")

func write_for(peer: int, snapshot: _Snapshot, properties: _PropertyPool, filter: Callable = _default_filter) -> Array[PackedByteArray]:
	var packet_buffer := _PacketBuffer.new(max_packet_size)
	var frame_buffer := StreamPeerBuffer.new()
	var node_buffer := StreamPeerBuffer.new()

	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()

	# Add a timestamp to every packet
	packet_buffer.packet_setup = func(packet: StreamPeerBuffer):
		packet.put_u32(snapshot.tick)

	# For each node
	for subject in properties.get_subjects():
		if not filter.call(subject): continue
		if not snapshot.is_auth(subject): continue

		var node := subject as Node
		assert(node.is_multiplayer_authority(), "Trying to serialize state for non-owned node!")
		assert(snapshot.is_auth(node), "Trying to serialize non-auth state node!")

		# Prepare buffers
		frame_buffer.clear()
		node_buffer.clear()

		# Write identifier
		if _write_identifier(node, peer, frame_buffer) != OK:
			continue

		# Write properties as-is
		# First into a buffer, so we can start with the state size
		for property in properties.get_properties_of(node):
			assert(snapshot.has_property(node, property), "Trying to serialize missing property %s on subject %s!" % [property, node])

			var value := snapshot.get_property(node, property)
			_write_property(node, property, value, node_buffer)

		# Indicate state size for the node
		varuint.encode(node_buffer.data_array.size(), frame_buffer)

		# Write node state
		frame_buffer.put_data(node_buffer.data_array)

		# Write frame into output buffer
		packet_buffer.push(frame_buffer.data_array)

	return packet_buffer.finish()

func read_from(peer: int, properties: _PropertyPool, buffer: StreamPeerBuffer, is_auth: bool = true) -> _Snapshot:
	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var node_buffer := StreamPeerBuffer.new()

	# Read tick
	var tick := buffer.get_u32()
	var snapshot := _Snapshot.new(tick)

	while buffer.get_available_bytes() > 0:
		# Read identity reference, data size, and data
		var idref := netref.decode(buffer) as _NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]

		# Resolve to identifier
		var identifier := _get_identity_server()._resolve_reference(peer, idref)
		if not identifier:
			# TODO(#563): Handle unknown IDs gracefully
			_logger.warning("Received unknown identity reference %s from #%s, skipping data", [idref, peer])
			continue
		var node := identifier.get_subject() as Node
		assert(is_instance_valid(node), "Where node?")

		# Read properties
		for property in properties.get_properties_of(node):
			if node_buffer.get_available_bytes() == 0: break

			var value := _read_property(node, property, node_buffer)
			snapshot.set_property(node, property, value)
		snapshot.set_auth(node, is_auth)

	return snapshot
