extends RefCounted
class_name _RingBuffer

var _data: Array
var _capacity: int
var _size: int = 0
var _head: int = 0

func _init(p_capacity: int):
	_capacity = p_capacity
	_data = []
	_data.resize(p_capacity)

func push(item):
	_data[_head] = item
	
	_size += 1
	_head = (_head + 1) % _capacity

func get_data() -> Array:
	if _size < _capacity:
		return _data.slice(0, _size)
	else:
		return _data

func size() -> int:
	return _size

func is_empty() -> bool:
	return _size == 0

func clear():
	_size = 0
	_head = 0
