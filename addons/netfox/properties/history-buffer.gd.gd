class_name _HistoryBuffer

# Typed as Dictionary[int, PropertyStoreSnapshot]
var _history: Dictionary

func get_closest_tick(tick: int) -> int:
	if _history.is_empty():
		return -1
	
	if _history.has(tick):
		return tick
	
	var earliest_tick: int = _history.keys().min()
	if tick < earliest_tick:
		return earliest_tick
	
	var latest_tick: int = _history.keys().max()
	if tick > latest_tick:
		return latest_tick
	
	return _history.keys() \
		.filter(func (key): return key < tick) \
		.max()

func get_closest_snapshot(tick: int) -> PropertyStoreSnapshot:
	var closest_tick = get_closest_tick(tick)
	if closest_tick == -1:
		return PropertyStoreSnapshot.new()
	
	return _history[closest_tick]

func get_earliest_tick() -> int:
	return _history.keys().min()

func get_latest_tick() -> int:
	return _history.keys().max()

func get_snapshot(tick: int) -> PropertyStoreSnapshot:
	return _history.get(tick, PropertyStoreSnapshot.new())

func add_if_missing(tick: int):
	if not _history.has(tick):
		_history[tick] = PropertyStoreSnapshot.new()

func set_snapshot(snapshot: PropertyStoreSnapshot, tick: int):
	_history[tick] = snapshot

func clear_history():
	_history.clear()

func size() -> int:
	return _history.size()

func has(tick: int) -> bool:
	return _history.has(tick)

func erase(tick: int):
	_history.erase(tick)

func merge(snapshot: PropertyStoreSnapshot, tick: int):
	if not _history.has(tick):
		_history[tick] = snapshot
		return
	
	for property in snapshot.get_properties():
		_history[tick].set_property(property.Path, property)
