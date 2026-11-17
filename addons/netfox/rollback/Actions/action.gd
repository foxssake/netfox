extends Resource
class_name Action

var action : int = -1

var tick : int = -1

var sender : NodePath

var data : Dictionary

func _init(_action : int = -1, _tick : int = -1, _sender : Node = null, _data : Dictionary = {}) -> void:
	action = _action
	tick = _tick
	if _sender != null:
		sender = _sender.get_path()
	data = _data

static func _decode(buffer : StreamPeerBuffer) -> Action:
	var a : Action = Action.new()
	
	a.tick = buffer.get_u64()
	a.action = buffer.get_8()
	a.sender = NetworkSchemas._netref().decode(buffer)
	a.data = NetworkSchemas.dictionary().decode(buffer)
	
	return Action.new()

func _encode(buffer : StreamPeerBuffer):
	buffer.put_u64(tick)
	buffer.put_8(action)
	NetworkSchemas._netref().encode(sender, buffer)
	NetworkSchemas.dictionary().encode(sender, buffer)
