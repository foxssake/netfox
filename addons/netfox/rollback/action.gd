extends Resource
class_name Action

var action : int = -1

var tick : int = -1

var sender : NodePath

static func _decode() -> Action:
	return Action.new()

func _encode() -> PackedByteArray:
	var array = PackedByteArray([])
	
	return []
