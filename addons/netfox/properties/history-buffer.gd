class_name _HistoryBuffer extends RefCounted

# Temporarily typed as Dictionary[int, ???]
var _buffer: Dictionary = {}

func get_snapshot(tick: int, default = {}):
	if _buffer.has(tick):
		return _buffer[tick]
	else:
		return default

func set_snapshot(data, tick: int):
	_buffer[tick] = data

func get_buffer() -> Dictionary:
	return _buffer

# Defaults
func clear():
	_buffer.clear()

func size() -> int:
	return _buffer.size()

func is_empty() -> bool:
	return _buffer.is_empty()

func has(key) -> bool:
	return _buffer.has(key)

func erase(key):
	_buffer.erase(key)
