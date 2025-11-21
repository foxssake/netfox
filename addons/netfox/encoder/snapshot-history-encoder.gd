extends RefCounted
class_name _SnapshotHistoryEncoder

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache
var _properties: Array[PropertyEntry]
var _serializers: Dictionary

var _version := -1
var _has_received := false

static var _logger := NetfoxLogger._for_netfox("_SnapshotHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache, p_serializers: Dictionary) -> void:
	_history = p_history
	_property_cache = p_property_cache
	_serializers = p_serializers

func set_properties(properties: Array[PropertyEntry]) -> void:
	if _properties != properties:
		_version = (_version + 1) % 256
		_properties = properties.duplicate()

func encode(tick: int, properties: Array[PropertyEntry]) -> PackedByteArray:
	var snapshot := _history.get_snapshot(tick)
	var buffer := StreamPeerBuffer.new()
	
	buffer.put_u8(_version)

	for property: PropertyEntry in properties:
		var path: String = property.to_string()
		var value = snapshot.get_value(path)
		
		# Serializers are guaranteed to exist because of RollbackSynchronizer._compile_serializers
		if _serializers.has(path):
			_serializers[path].encode(value, buffer)
		else:
			# Safety fallback if something went wrong with compilation
			var data: PackedByteArray = var_to_bytes(value)
			buffer.put_u32(data.size())
			buffer.put_data(data)

	return buffer.data_array

func decode(data: Variant, properties: Array[PropertyEntry]) -> _PropertySnapshot:
	var result := _PropertySnapshot.new()
	
	# Handle case where data might be empty
	if data.is_empty():
		return result
		
	var buffer := StreamPeerBuffer.new()
	if data is PackedByteArray:
		buffer.data_array = data
	elif data is Array:
		# Fallback
		return _decode_legacy_array(data, properties)

	# Read Version
	var packet_version: int = buffer.get_u8()

	if packet_version != _version:
		if not _has_received:
			_version = packet_version
		else:
			_logger.warning("Version mismatch! own: %d, received: %s", [_version, packet_version])
			return result

	_has_received = true

	for property: PropertyEntry in properties:
		if buffer.get_available_bytes() == 0:
			break
		
		var path: String = property.to_string()
		
		if _serializers.has(path):
			var val = _serializers[path].decode(buffer)
			result.set_value(path, val)
		else:
			# Fallback decode
			var size: int = buffer.get_u32()
			var bytes: Array = buffer.get_data(size)
			result.set_value(path, bytes_to_var(bytes))

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

func _decode_legacy_array(data: Array, properties: Array[PropertyEntry]) -> _PropertySnapshot:
	# Copied from original implementation just in case
	var result := _PropertySnapshot.new()
	var packet_version = data.pop_back()
	if packet_version != _version:
		return result
	for i: int in range(0, mini(data.size(), properties.size())):
		result.set_value(properties[i].to_string(), data[i])
	return result
