extends RefCounted
class_name _BiMap

# Maps one-to-one associations in a bidirectional way

# TODO: Tests

var _keys_to_values := {}
var _values_to_keys := {}

func put(key: Variant, value: Variant) -> void:
	_keys_to_values[key] = value
	_values_to_keys[value] = key

func get_value(key: Variant) -> Variant:
	return _keys_to_values[key]

func get_key(value: Variant) -> Variant:
	return _values_to_keys[value]

func has_key(key: Variant) -> bool:
	return _keys_to_values.has(key)

func has_value(value: Variant) -> bool:
	return _values_to_keys.has(value)

func erase_key(key: Variant) -> bool:
	if not has_key(key):
		return false

	var value = get_value(key)
	_values_to_keys.erase(value)
	_keys_to_values.erase(key)
	return true

func erase_value(value: Variant) -> bool:
	if not has_value(value):
		return false

	var key = get_key(value)
	_values_to_keys.erase(value)
	_keys_to_values.erase(key)
	return true

func size() -> int:
	return _keys_to_values.size()

func keys() -> Array:
	return _keys_to_values.keys()

func values() -> Array:
	return _values_to_keys.keys()
