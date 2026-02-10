extends RefCounted
class_name ObjectSnapshot

var _object: Object
var _is_auth: bool = false
var _data: Dictionary = {}

func _init(p_object: Object) -> void:
	_object = p_object

func duplicate() -> ObjectSnapshot:
	var result := ObjectSnapshot.new(_object)
	result._is_auth = _is_auth
	result._data = _data.duplicate()
	return result

func get_value(property: NodePath, default: Variant = null) -> Variant:
	return _data.get(property, default)

func set_value(property: NodePath, value: Variant) -> void:
	_data[property] = value

func has_value(property: NodePath) -> bool:
	return _data.has(property)

func record_property(property: NodePath) -> void:
	set_value(property, _object.get_indexed(property))

func apply() -> void:
	for property in properties():
		var value := get_value(property)
		_object.set_indexed(property, value)

func is_auth() -> bool:
	return _is_auth

func set_auth(p_auth: bool) -> void:
	_is_auth = p_auth

func properties() -> Array:
	return _data.keys()

func _to_string() -> String:
	return "ObjectSnapshot(%s(%d), %s, %s)" % [_object, (_object as Node).get_multiplayer_authority() if _object is Node else -1, _is_auth, _data]
