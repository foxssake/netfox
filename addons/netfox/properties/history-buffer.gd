class_name _HistoryBuffer extends RefCounted

# Typed as Dictionary[int, _PropertyStoreSnapshot]
var _buffer: Dictionary = {}

func get_snapshot(tick: int) -> _PropertyStoreSnapshot:
	if _buffer.has(tick):
		return _buffer[tick]
	else:
		return _PropertyStoreSnapshot.new()

# TODO: Swap arg order
func set_snapshot(tick: int, data):
	if data is Dictionary:
		var snapshot := _PropertyStoreSnapshot.from_dictionary(data)
		_buffer[tick] = snapshot
	elif data is _PropertyStoreSnapshot:
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

func get_history(tick: int) -> _PropertyStoreSnapshot:
	var closest_tick = get_closest_tick(tick)

	if closest_tick == -1:
		return _PropertyStoreSnapshot.new()

	return _buffer[closest_tick]

func trim(earliest_tick_to_keep: int = NetworkRollback.history_start):
	var ticks := _buffer.keys()
	for tick in ticks:
		if tick < earliest_tick_to_keep:
			_buffer.erase(tick)

func merge(data: _PropertyStoreSnapshot, tick:int):
	set_snapshot(tick, get_snapshot(tick).merge(data))

func clear():
	_buffer.clear()

func size() -> int:
	return _buffer.size()

func is_empty() -> bool:
	return _buffer.is_empty()

func has(tick) -> bool:
	return _buffer.has(tick)

func ticks() -> Array:
	return _buffer.keys()

func erase(tick):
	_buffer.erase(tick)
