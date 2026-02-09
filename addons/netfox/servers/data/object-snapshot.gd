extends RefCounted
class_name ObjectSnapshot

var _object: Object
var _is_auth: bool
var _data: Dictionary = {}

func get_value(property: NodePath) -> Variant:
	return _data[property]

func set_value(property: NodePath, value: Variant) -> void:
	_data[property] = value
