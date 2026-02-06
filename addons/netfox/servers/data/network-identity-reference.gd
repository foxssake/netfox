class_name _NetworkIdentityReference
extends RefCounted

var _full_name: String = ""
var _id: int = -1

static func of_full_name(full_name: String) -> _NetworkIdentityReference:
	var reference := _NetworkIdentityReference.new()
	reference._full_name = full_name
	return reference

static func of_id(id: int) -> _NetworkIdentityReference:
	var reference := _NetworkIdentityReference.new()
	reference._id = id
	return reference

func has_id() -> bool:
	return _id >= 0

func get_id() -> int:
	return _id

func get_full_name() -> String:
	return _full_name

func equals(other: Variant) -> bool:
	if other is _NetworkIdentityReference:
		return _full_name == other._full_name and _id == other._id
	return false

func _to_string() -> String:
	if has_id():
		return "NetworkIdentityReference#%d" % [_id]
	else:
		return "NetworkIdentityReference(%s)" % [_full_name]
