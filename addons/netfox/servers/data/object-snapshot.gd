extends RefCounted
class_name _ObjectSnapshot

# Represents snapshot data for a single object, by storing the object's values
# for specified properties

var _object: Object
var _is_auth: bool = false
var _data: Dictionary = {}

func _init(p_object: Object) -> void:
	_object = p_object

func duplicate() -> _ObjectSnapshot:
	var result := _ObjectSnapshot.new(_object)
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
	_data[property] = _object.get_indexed(property)

func record_properties(properties: Array, tick_snapshot: _Snapshot, is_auth: bool = false) -> void:
	var object := _object
	var data := _data
	var tick_data: Dictionary = tick_snapshot._data_for(object)
	for property in properties:
		var value: Variant = object.get_indexed(property)
		data[property] = value
		tick_data[property] = value
	_is_auth = is_auth
	tick_snapshot.set_auth(object, is_auth)

func apply() -> void:
	var object := _object
	var data := _data
	for property in data:
		object.set_indexed(property, data[property])

func is_auth() -> bool:
	return _is_auth

func set_auth(p_auth: bool) -> void:
	_is_auth = p_auth

func properties() -> Array:
	return _data.keys()

func _to_string() -> String:
	return "ObjectSnapshot(%s(%d), %s, %s)" % [_object, (_object as Node).get_multiplayer_authority() if _object is Node else -1, _is_auth, _data]
