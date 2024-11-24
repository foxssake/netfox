extends RefCounted
class_name _Set

var _data: Dictionary = {}

func add(value):
	_data[value] = true

func has(value) -> bool:
	return _data.has(value)

func erase(value):
	return _data.erase(value)

func clear():
	_data.clear()

func values() -> Array:
	return _data.keys()
