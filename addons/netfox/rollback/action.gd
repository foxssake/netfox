extends Resource
class_name Action

var action : int = -1

var tick : int = -1

var sender : NodePath

var data : Dictionary

static func _decode(buffer : StreamPeerBuffer) -> Action:
	var a : Action = Action.new()
	
	a.tick = buffer.get_u64()
	a.action = buffer.get_8()
	a.sender = NetworkIdentityServer._get_identifier_by_local_id(buffer.get_64()).get_full_name()
	var dataLen : int = buffer.get_u32()
	a.data = bytes_to_var(buffer.get_data(dataLen))
	
	return Action.new()

func _encode(buffer : StreamPeerBuffer):
	buffer.put_u64(tick)
	buffer.put_8(action)
	buffer.put_64(NetworkIdentityServer._get_identifier_by_name(sender).get_local_id())
	
	var dataBytes : PackedByteArray = var_to_bytes(data)
	buffer.put_u32(dataBytes.size())
	buffer.put_data(dataBytes)
