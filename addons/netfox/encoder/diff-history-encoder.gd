extends RefCounted
class_name _DiffHistoryEncoder

var sanitize: bool = true

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

static var _logger := _NetfoxLogger.for_netfox("DiffHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func encode(tick: int, reference_tick: int) -> Dictionary:
	var snapshot := _history.get_snapshot(tick)

	var reference_snapshot := _history.get_history(reference_tick)
	var diff_snapshot := reference_snapshot.make_patch(snapshot)

	return diff_snapshot.as_dictionary()

func decode(data: Dictionary) -> _PropertySnapshot:
	return _PropertySnapshot.from_dictionary(data)

func apply(tick: int, snapshot: _PropertySnapshot, reference_tick: int, sender: int = -1) -> bool:
	if tick < NetworkRollback.history_start:
		# State too old!
		_logger.error(
			"Received diff snapshot for @%d, rejecting because older than %s frames",
			[tick, NetworkRollback.history_limit]
		)
		return false

	if snapshot.is_empty():
		return true

	if sanitize and sender > 0:
		snapshot.sanitize(sender, _property_cache)
		if snapshot.is_empty():
			_logger.warning("Received invalid diff from #%s for @%s", [sender, tick])
			return false

	if not _history.has(reference_tick):
		# Reference tick missing, hope for the best
		_logger.warning("Reference tick %d missing for applying %d", [reference_tick, tick])

	var reference_snapshot := _history.get_snapshot(reference_tick)
	_history.set_snapshot(tick, reference_snapshot.merge(snapshot))
	return true
