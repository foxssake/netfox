extends RefCounted
class_name _RedundantHistoryEncoder

var redundancy: int = 4:
	get = get_redundancy,
	set = set_redundancy

var _history: _PropertyHistoryBuffer
var _properties: Array[PropertyEntry]
var _property_cache: PropertyCache
var _schema_handler: _NetworkSchema

var _version := 0
var _has_received := false

var _logger := NetfoxLogger._for_netfox("RedundantHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache, p_schema_handler: _NetworkSchema):
	_history = p_history
	_property_cache = p_property_cache
	_schema_handler = p_schema_handler

func get_redundancy() -> int:
	return redundancy

func set_redundancy(p_redundancy: int):
	if p_redundancy <= 0:
		_logger.warning("Attempting to set redundancy to %d, which would send no data!", [p_redundancy])
		return

	redundancy = p_redundancy

func set_properties(properties: Array[PropertyEntry]) -> void:
	if _properties != properties:
		_version = (_version + 1) % 256
		_properties = properties.duplicate()

func encode(tick: int, properties: Array[PropertyEntry]) -> PackedByteArray:
	if _history.is_empty():
		return PackedByteArray()

	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(_version)

	for i in range(mini(redundancy, _history.size())):
		var offset_tick := tick - i
		if offset_tick < _history.get_earliest_tick():
			break

		var snapshot := _history.get_snapshot(offset_tick)
		for property in properties:
			var path := property.to_string()
			var value := snapshot.get_value(path)
			_schema_handler.encode(path, value, buffer)

	return buffer.data_array

func decode(data: PackedByteArray, properties: Array[PropertyEntry]) -> Array[_PropertySnapshot]:
	var result: Array[_PropertySnapshot] = []

	if data.is_empty():
		return result

	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var packet_version := buffer.get_u8()

	if packet_version != _version:
		if not _has_received:
			# First packet, assume version is OK
			_version = packet_version
		else:
			# Version mismatch, can't parse
			_logger.warning("Version mismatch! own: %d, received: %s", [_version, packet_version])
			return result

	_has_received = true

	while buffer.get_available_bytes() > 0:
		var snapshot = _PropertySnapshot.new()

		for property in properties:
			# Stop if we run out of data mid-snapshot
			if buffer.get_available_bytes() == 0:
				break

			var path := property.to_string()
			var value := _schema_handler.decode(path, buffer)

			snapshot.set_value(path, value)

		result.append(snapshot)

	return result

# Returns earliest new tick as int, or -1 if no new ticks applied
func apply(tick: int, snapshots: Array[_PropertySnapshot], sender: int = 0) -> int:
	var earliest_new_tick = -1

	for i in range(snapshots.size()):
		var offset_tick := tick - i
		var snapshot := snapshots[i]

		if offset_tick < NetworkRollback.history_start:
			# Data too old
			_logger.warning(
				"Received data for %s, rejecting because older than %s frames",
				[offset_tick, NetworkRollback.history_limit]
			)
			continue

		if sender > 0:
			snapshot.sanitize(sender, _property_cache)
			if snapshot.is_empty():
				# No valid properties ( probably after sanitize )
				_logger.warning("Received invalid data from %d for tick %d", [sender, tick])
				continue

		var known_snapshot := _history.get_snapshot(offset_tick)
		if not known_snapshot.equals(snapshot):
			# Received a new snapshot, store and emit signal
			_history.set_snapshot(offset_tick, snapshot)
			earliest_new_tick = offset_tick

	return earliest_new_tick
