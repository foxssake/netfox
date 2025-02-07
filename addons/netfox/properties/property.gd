extends RefCounted
class_name Property

var path: String
var value: Variant

func serialize() -> Dictionary:
	var serialized: Dictionary = {}
	serialized[0] = path
	serialized[1] = value
	return serialized

static func deserialize(data) -> Property:
	var deserialized := Property.new()
	deserialized.path = data[0]
	deserialized.value = data[1]
	return deserialized
