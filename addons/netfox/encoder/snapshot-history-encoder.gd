extends RefCounted
class_name _SnapshotHistoryEncoder

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

static var _logger := _NetfoxLogger.for_netfox("_SnapshotHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func encode(tick: int, property_config: Array[PropertyEntry]) -> Array:
	var snapshot := _history.get_snapshot(tick)
	var data := []
	data.resize(property_config.size())

	for i in range(property_config.size()):
		data[i] = snapshot.get_value(property_config[i].to_string())

	return data

func decode(data: Array, property_config: Array[PropertyEntry]) -> _PropertySnapshot:
	var result := _PropertySnapshot.new()
	for i in range(property_config.size()):
		result.set_value(property_config[i].to_string(), data[i])
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
