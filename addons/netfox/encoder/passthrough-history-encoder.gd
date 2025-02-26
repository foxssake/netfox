extends RefCounted
class_name PassthroughHistoryEncoder

var sanitize: bool = true

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func encode(tick: int) -> Dictionary:
	return _history.get_snapshot(tick).as_dictionary()

func decode(data: Dictionary, sender: int = -1) -> _PropertySnapshot:
	var snapshot := _PropertySnapshot.from_dictionary(data)
	if sanitize and sender > 0:
		snapshot.sanitize(sender, _property_cache)
		if snapshot.is_empty(): return null

	return _PropertySnapshot.from_dictionary(data)

func apply(tick: int, snapshot: _PropertySnapshot):
	# TODO: Sanitize + limit checks
	_history.set_snapshot(tick, snapshot)
