extends RefCounted
class_name _BiMap

# Maps one-to-one associations in a bidirectional way

var _keys_to_values := {}
var _values_to_keys := {}

func put(key: Variant, value: Variant) -> void:
	var old_value = _keys_to_values.get(key)
	var old_key = _values_to_keys.get(value)

	if old_value != null: _values_to_keys.erase(old_value)
	if old_key != null: _keys_to_values.erase(old_key)

	_keys_to_values[key] = value
	_values_to_keys[value] = key

func get_by_key(key: Variant) -> Variant:
	return _keys_to_values.get(key)

func get_by_value(value: Variant) -> Variant:
	return _values_to_keys.get(value)

func has_key(key: Variant) -> bool:
	return _keys_to_values.has(key)

func has_value(value: Variant) -> bool:
	return _values_to_keys.has(value)

func erase_key(key: Variant) -> bool:
	if not has_key(key):
		return false

	var value = get_by_key(key)
	_values_to_keys.erase(value)
	_keys_to_values.erase(key)
	return true

func erase_value(value: Variant) -> bool:
	if not has_value(value):
		return false

	var key = get_by_value(value)
	_values_to_keys.erase(value)
	_keys_to_values.erase(key)
	return true

func size() -> int:
	return _keys_to_values.size()

func keys() -> Array:
	return _keys_to_values.keys()

func values() -> Array:
	return _values_to_keys.keys()
