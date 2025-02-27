extends RefCounted
class_name PassthroughHistoryEncoder

var sanitize: bool = true

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

static var _logger := _NetfoxLogger.for_netfox("PassthroughHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func encode(tick: int) -> Dictionary:
	return _history.get_snapshot(tick).as_dictionary()

func decode(data: Dictionary) -> _PropertySnapshot:
	var snapshot := _PropertySnapshot.from_dictionary(data)

	return _PropertySnapshot.from_dictionary(data)

func apply(tick: int, snapshot: _PropertySnapshot, sender: int = -1):
	if tick < NetworkRollback.history_start:
		# State too old!
		_logger.error("Received full snapshot for %s, rejecting because older than %s frames", [tick, NetworkRollback.history_limit])
		return false

	if sanitize and sender > 0:
		snapshot.sanitize(sender, _property_cache)
		if snapshot.is_empty(): return false

	_history.set_snapshot(tick, snapshot)
	return true
