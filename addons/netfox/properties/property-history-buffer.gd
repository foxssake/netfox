extends _HistoryBuffer
class_name _PropertyHistoryBuffer

func get_snapshot(tick: int) -> _PropertySnapshot:
	if _buffer.has(tick):
		return _buffer[tick]
	else:
		return _PropertySnapshot.new()

func set_snapshot(tick: int, data) -> void:
	if data is Dictionary:
		var snapshot := _PropertySnapshot.from_dictionary(data)
		super(tick, snapshot)
	elif data is _PropertySnapshot:
		super(tick, data)
	else:
		push_error("Data not a PropertSnapshot! %s" % [data])

func get_history(tick: int) -> _PropertySnapshot:
	var snapshot = super(tick)

	return snapshot if snapshot else _PropertySnapshot.new()

func trim(earliest_tick_to_keep: int = NetworkRollback.history_start) -> void:
	super(earliest_tick_to_keep)

func merge(data: _PropertySnapshot, tick:int) -> void:
	set_snapshot(tick, get_snapshot(tick).merge(data))
