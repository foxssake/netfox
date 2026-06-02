extends _BaseSnapshotSerializer
class_name _SparseSnapshotSerializer

static func _static_init():
	_logger = NetfoxLogger._for_netfox("SparseSnapshotSerializer")

func write_for(peer: int, snapshot: _Snapshot, properties: _PropertyPool, filter: Callable = _default_filter) -> Array[PackedByteArray]:
	var packet_buffer := _PacketBuffer.new(max_packet_size)
	var frame_buffer := StreamPeerBuffer.new()
	var node_buffer := StreamPeerBuffer.new()

	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var varbits := NetworkSchemas._varbits()

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

		# Write frame, starting with identifier
		if _write_identifier(node, peer, frame_buffer) != OK:
			continue

		var node_props := properties.get_properties_of(node)
		var changed_bits := _Bitset.new(node_props.size())

		for i in node_props.size():
			var property := node_props[i]
			if not snapshot.has_property(node, property):
				continue

			changed_bits.set_bit(i)
			var value := snapshot.get_property(node, property)
			_write_property(node, property, value, node_buffer)

		varuint.encode(node_buffer.data_array.size(), frame_buffer)		# Node props len
		varbits.encode(changed_bits, frame_buffer)						# Changed prop bits
		frame_buffer.put_data(node_buffer.data_array)					# Changed props

		# Write frame into output buffer
		packet_buffer.push(frame_buffer.data_array)

	return packet_buffer.finish()

func read_from(peer: int, properties: _PropertyPool, buffer: StreamPeerBuffer, is_auth: bool = true) -> _Snapshot:
	var netref := NetworkSchemas._netref()
	var varuint := NetworkSchemas.varuint()
	var varbits := NetworkSchemas._varbits()
	var node_buffer := StreamPeerBuffer.new()

	# Grab ticks
	var tick := buffer.get_u32()
	var snapshot := _Snapshot.new(tick)

	while buffer.get_available_bytes() > 0:
		# Read header, including identity reference
		var idref := netref.decode(buffer) as _NetworkIdentityReference
		var node_data_size := varuint.decode(buffer) as int
		var changed_bits := varbits.decode(buffer) as _Bitset
		node_buffer.data_array = buffer.get_partial_data(node_data_size)[1]

		# Resolve to identifier
		var identifier := _get_identity_server()._resolve_reference(peer, idref)
		if not identifier:
			# TODO(#563): Handle unknown IDs gracefully
			_logger.warning("Received unknown identity reference %s, skipping data", [idref])
			break
		var node := identifier.get_subject() as Node

		# Read changed properties
		var node_props := properties.get_properties_of(node)
		for idx in changed_bits.get_set_indices():
			var property := node_props[idx]
			var value := _read_property(node, property, node_buffer)
			snapshot.set_property(node, property, value)
		snapshot.set_auth(node, is_auth)
	return snapshot
