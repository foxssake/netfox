extends RefCounted
class_name _Set

var _data: Dictionary = {}
var _iterator_idx: int = -1

func add(value):
	_data[value] = true

func has(value) -> bool:
	return _data.has(value)

func size() -> int:
	return _data.size()

func is_empty() -> bool:
	return _data.is_empty()

func erase(value):
	return _data.erase(value)

func clear():
	_data.clear()

func values() -> Array:
	return _data.keys()

func _iter_init(arg) -> bool:
	_iterator_idx = 0
	return _can_iterate()

func _iter_next(arg) -> bool:
	_iterator_idx += 1
	return _can_iterate()

func _iter_get(arg):
	return _data.keys()[_iterator_idx]

func _can_iterate() -> bool:
	if _data.is_empty() or _iterator_idx >= _data.size():
		_iterator_idx = -1
		return false
	return true
