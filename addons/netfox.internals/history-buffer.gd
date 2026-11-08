extends RefCounted
class_name _HistoryBuffer

# Maps ticks (int) to arbitrary data, stored in a sliding ring buffer

var _capacity := 64
var _buffer := []
var _previous := []

var _tail := 0
var _head := 0
var _slot := 0

static func of(capacity: int, data: Dictionary) -> _HistoryBuffer:
	var history_buffer := _HistoryBuffer.new(capacity)
	for idx in data:
		history_buffer.set_at(idx, data[idx])
	return history_buffer

func _init(capacity: int = 64):
	_capacity = capacity
	_buffer.resize(_capacity)
	_previous.resize(_capacity)
	_slot = 0

func duplicate(deep: bool = false) -> _HistoryBuffer:
	var buffer := _HistoryBuffer.new(_capacity)

	buffer._buffer = _buffer.duplicate(deep)
	buffer._previous = _previous.duplicate()
	buffer._tail = _tail
	buffer._head = _head
	buffer._slot = _head % _capacity

	return buffer

func push(value: Variant) -> void:
	var slot := _slot
	_buffer[slot] = value
	_previous[slot] = _head
	_head += 1
	slot += 1
	if slot == _capacity:
		slot = 0
	_slot = slot
	var overflow: int = _head - _tail - _capacity
	if overflow > 0:
		_tail += overflow

func pop() -> Variant:
	assert(is_not_empty(), "History buffer is empty!")

	var value = _buffer[_tail % _capacity]
	_tail += 1
	return value

func values() -> Array:
	var result := []
	for i in range(_tail, _head + 1):
		if i == _previous[i % _capacity]:
			result.append(_buffer[i % _capacity])
	return result

func set_at(at: int, value: Variant) -> void:
	# Why does this need so many branches?
	var head := _head
	if _tail == head:
		# Buffer is empty, jump to specified index
		_tail = at
		_head = at
		_slot = at % _capacity
		push(value)
	elif at < head - _capacity:
		# Trying to set something that would wrap back around and overwrite
		# current data
		return
	elif at == head:
		# Simply adding a new item
		push(value)
	elif at < head:
		var slot := at % _capacity
		_buffer[slot] = value
		# Update prev-buffer
		var previous := _previous
		var capacity := _capacity
		for i in range(at, head):
			var i_slot := i % capacity
			if previous[i_slot] == i:
				break
			previous[i_slot] = at
		if at < _tail:
			_tail = at
	elif at >= head + _capacity:
		# We're leaving all data behind
		_tail = at
		_head = at
		_slot = at % _capacity

		_previous.fill(null)
		_buffer.fill(null)

		push(value)
	else:
		# Skipping forward a bit
		var previous_idx := head - 1
		var previous := _previous
		var capacity := _capacity
		var slot := _slot
		while head < at:
			previous[slot] = previous_idx
			head += 1
			slot += 1
			if slot == capacity:
				slot = 0
		_head = head
		_slot = slot
		var overflow: int = head - _tail - capacity
		if overflow > 0:
			_tail += overflow

		push(value)

func has_at(at: int) -> bool:
	var head := _head
	if _tail == head:
		return false
	if at < head - _capacity or at >= head:
		return false
	return _previous[at % _capacity] == at

func get_at(at: int, default: Variant = null) -> Variant:
	var head := _head
	if _tail == head or at < head - _capacity or at >= head:
		return default
	var slot := at % _capacity
	if _previous[slot] != at:
		return default
	return _buffer[slot]

func has_latest_at(at: int) -> bool:
	return _tail != _head and at >= _tail

func size() -> int:
	return _head - _tail

func capacity() -> int:
	return _capacity

func get_earliest_index() -> int:
	return _tail

func get_latest_index() -> int:
	return _head - 1

func get_latest_index_at(at: int) -> int:
	if _tail == _head or at < _tail:
		return -1
	if at >= _head:
		return _head - 1

	return _previous[at % _capacity]

func get_latest_at(at: int) -> Variant:
	if _tail == _head or at < _tail:
		return null
	var index := _head - 1
	if at < _head:
		index = _previous[at % _capacity]
	return _buffer[index % _capacity]

func clear():
	_tail = _head

func is_empty() -> bool:
	return _tail == _head

func is_not_empty() -> bool:
	return _tail != _head
