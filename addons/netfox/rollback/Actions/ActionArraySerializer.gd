extends NetworkSchemaSerializer
class_name ActionArraySerializer

func encode(value: Variant, buffer: StreamPeerBuffer) -> void:
	var v : Array[Action] = value as Array[Action]
	
	for a : Action in v:
		a._encode(buffer)

func decode(buffer: StreamPeerBuffer) -> Variant:
	var actions : Array[Action]
	
	while buffer.get_position() < buffer.get_size():
		actions.push_back(Action._decode(buffer))
	
	return actions
