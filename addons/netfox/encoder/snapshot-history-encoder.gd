extends RefCounted
class_name _SnapshotHistoryEncoder

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache
var _properties: Array[PropertyEntry]

var _version := -1
var _has_received := false

static var _logger := NetfoxLogger._for_netfox("_SnapshotHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func set_properties(properties: Array[PropertyEntry]) -> void:
	if _properties != properties:
		_version = (_version + 1) % 256
		_properties = properties.duplicate()

func encode(tick: int, properties: Array[PropertyEntry]) -> Array:
	var snapshot := _history.get_snapshot(tick)
	var data := []
	data.resize(properties.size())

	for i in range(properties.size()):
		data[i] = snapshot.get_value(properties[i].to_string())
	data.append(_version)

	return data

func decode(data: Array, properties: Array[PropertyEntry]) -> _PropertySnapshot:
	var result := _PropertySnapshot.new()
	var packet_version = data.pop_back()

	if packet_version != _version:
		if not _has_received:
			# First packet, assume version is OK
			_version = packet_version
		else:
			# Version mismatch, can't parse
			_logger.warning("Version mismatch! own: %d, received: %s", [_version, packet_version])
			return result

	if properties.size() != data.size():
		_logger.warning("Received snapshot with %d entries, with %d known - parsing as much as possible", [data.size(), properties.size()])

	for i in range(0, mini(data.size(), properties.size())):
		result.set_value(properties[i].to_string(), data[i])

	_has_received = true

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
