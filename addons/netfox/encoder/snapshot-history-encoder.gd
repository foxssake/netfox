extends RefCounted
class_name _SnapshotHistoryEncoder

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache
var _properties: Array[PropertyEntry]
var _schema_handler: _NetworkSchema

var _version := -1
var _has_received := false

static var _logger := NetfoxLogger._for_netfox("_SnapshotHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache, p_schema_handler: _NetworkSchema) -> void:
	_history = p_history
	_property_cache = p_property_cache
	_schema_handler = p_schema_handler

func set_properties(properties: Array[PropertyEntry]) -> void:
	if _properties != properties:
		_version = (_version + 1) % 256
		_properties = properties.duplicate()

func encode(tick: int, properties: Array[PropertyEntry]) -> PackedByteArray:
	var snapshot := _history.get_snapshot(tick)
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_u8(_version)

	for property in properties:
		var path: String = property.to_string()
		var value = snapshot.get_value(path)
		_schema_handler.encode(path, value, buffer)

	return buffer.data_array

func decode(data: PackedByteArray, properties: Array[PropertyEntry]) -> _PropertySnapshot:
	var result := _PropertySnapshot.new()

	if data.is_empty():
		return result

	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	var packet_version: int = buffer.get_u8()

	if packet_version != _version:
		if not _has_received:
			_version = packet_version
		else:
			_logger.warning("Version mismatch! own: %d, received: %s", [_version, packet_version])
			return result

	_has_received = true

	for property in properties:
		if buffer.get_available_bytes() == 0:
			_logger.warning("Received snapshot with %d properties, expected %d!", [result.size(), properties.size()])
			break

		var path := property.to_string()
		var value := _schema_handler.decode(path, buffer)
		result.set_value(path, value)

	return result

func apply(tick: int, snapshot: _PropertySnapshot, sender: int = -1) -> bool:
	if tick < NetworkRollback.history_start:
		# State too old!
		_logger.error("Received full snapshot for %s, rejecting because older than %s frames", [tick, NetworkRollback.history_limit])
		return false

	if sender > 0:
		snapshot.sanitize(sender, _property_cache)
		if snapshot.is_empty(): return false

	_history.set_snapshot(tick, snapshot)
	return true
