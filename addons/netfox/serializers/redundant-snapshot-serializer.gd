extends _BaseSnapshotSerializer
class_name _RedundantSnapshotSerializer

var _dense_serializer: _DenseSnapshotSerializer

static func _static_init():
	_logger = NetfoxLogger._for_netfox("RedundantSnapshotSerializer")

func _init(p_schemas: _NetworkSchema):
	super(p_schemas)
	_dense_serializer = _DenseSnapshotSerializer.new(_schemas)

func write_for(peer: int, snapshots: Array[Snapshot], properties: _PropertyPool, buffer: StreamPeerBuffer = null) -> PackedByteArray:
	var varuint := NetworkSchemas.varuint()

	if buffer == null:
		buffer = StreamPeerBuffer.new()

	# TODO(#???): How about encoding the first snapshot as-is, and then the rest as diffs
	for snapshot in snapshots:
		var serialized := _dense_serializer.write_for(peer, snapshot, properties)

		# Write size and snapshot
		varuint.encode(serialized.size(), buffer)
		buffer.put_data(serialized)

	return buffer.data_array

func read_from(peer: int, properties: _PropertyPool, buffer: StreamPeerBuffer, is_auth: bool = true) -> Array[Snapshot]:
	var varuint := NetworkSchemas.varuint()

	var snapshots := [] as Array[Snapshot]
	while buffer.get_available_bytes() > 0:
		var snapshot_size := varuint.decode(buffer)
		var snapshot_buffer := StreamPeerBuffer.new()
		snapshot_buffer.data_array = buffer.get_partial_data(snapshot_size)[1]
		
		var snapshot := _dense_serializer.read_from(peer, properties, snapshot_buffer, is_auth)
		snapshots.append(snapshot)
	return snapshots
