extends RefCounted
class_name _HistoryBuffer

# Maps ticks (int) to arbitrary data
var _capacity := 64
var _buffer := []
var _previous := []

var _tail := 0
var _head := 0

static func of(capacity: int, data: Dictionary) -> _HistoryBuffer:
	var history_buffer := _HistoryBuffer.new(capacity)
	for idx in data:
		history_buffer.set_at(idx, data[idx])
	return history_buffer

func _init(capacity: int = 64):
	_capacity = capacity
	_buffer.resize(_capacity)
	_previous.resize(_capacity)

func duplicate(deep: bool = false) -> _HistoryBuffer:
	var buffer := _HistoryBuffer.new(_capacity)

	buffer._buffer = _buffer.duplicate(deep)
	buffer._previous = _previous.duplicate()
	buffer._tail = _tail
	buffer._head = _head

	return buffer

func push(value: Variant) -> void:
	_buffer[_head % _capacity] = value
	_previous[_head % _capacity] = _head
	_head += 1
	_tail += maxi(0, size() - capacity())

func pop() -> Variant:
	assert(is_not_empty(), "History buffer is empty!")

	var value = _buffer[_tail % _capacity]
	_tail += 1
	return value

func set_at(at: int, value: Variant) -> void:
	# Why does this need so many branches?
	if is_empty():
		# Buffer is empty, jump to specified index
		_tail = at
		_head = at
		push(value)
	elif at < _head - capacity():
		# Trying to set something that would wrap back around and overwrite
		# current data
		return
	elif at == _head:
		# Simply adding a new item
		push(value)
	elif at < _head:
		_buffer[at % _capacity] = value
		# Update prev-buffer
		for i in range(at, _head):
			if _previous[i % _capacity] == i:
				break
			_previous[i % _capacity] = at
		_tail = mini(_tail, at)
	elif at >= _head + _capacity:
		# We're leaving all data behind
		_tail = at
		_head = at

		_previous.fill(null)
		_buffer.fill(null)

		push(value)
	elif at >= _head:
		var previous := _head - 1
		while _head < at:
			_previous[_head % _capacity] = previous
			_head += 1
		_tail += maxi(0, size() - _capacity)

		push(value)

func has_at(at: int) -> bool:
	if is_empty(): return false
	if at < _head - capacity(): return false
	if at >= _head: return false
	return _previous[at % _capacity] == at

func get_at(at: int, default: Variant = null) -> Variant:
	if not has_at(at):
		return default
	return _buffer[at % _capacity]

func has_latest_at(at: int) -> bool:
	if is_empty(): return false
	if at < _tail: return false
	return true

func size() -> int:
	return _head - _tail

func capacity() -> int:
	return _capacity

func get_earliest_index() -> int:
	return _tail

func get_latest_index() -> int:
	return _head - 1

func get_latest_index_at(at: int) -> int:
	if not has_latest_at(at):
		return -1
	if at >= _head:
		return get_latest_index()

	return _previous[at % _capacity]

func get_latest_at(at: int) -> Variant:
	return get_at(get_latest_index_at(at))

func clear():
	_tail = _head

func is_empty() -> bool:
	return size() == 0

func is_not_empty() -> bool:
	return not is_empty()
