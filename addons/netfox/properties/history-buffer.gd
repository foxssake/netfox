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

func get_closest_tick(tick: int) -> int:
	if _buffer.has(tick):
		return tick
	
	if _buffer.is_empty():
		return -1
	
	var earliest_tick = _buffer.keys().min()
	
	if tick < earliest_tick:
		return earliest_tick
	
	var latest_tick = _buffer.keys().max()
	
	if tick > latest_tick:
		return latest_tick
	
	return _buffer.keys() \
		.filter(func (key): return key < tick) \
		.max()
	
func get_history(tick: int) -> Dictionary:
	var closest_tick = get_closest_tick(tick)
	
	if closest_tick == -1:
		return {}
	
	return _buffer[closest_tick]

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
