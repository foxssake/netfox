extends RefCounted
class_name _IdentityPacketSerializer

# Serializes a set of (ID, full name) pairs
#
# Used by NetworkIdentityServer, when sending local IDs to other peers

# ids: Dictionary[full_name, local_id]
func serialize(ids: Dictionary) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	var varuint := NetworkSchemas.varuint()

	for full_name in ids.keys():
		var id := ids[full_name] as int

		buffer.put_utf8_string(full_name)
		varuint.encode(ids[full_name], buffer)

	return buffer.data_array

# return: Dictionary[full_name, local_id]
func deserialize(data: PackedByteArray) -> Dictionary:
	var ids := {}
	var varuint := NetworkSchemas.varuint()
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	while buffer.get_available_bytes() > 0:
		var full_name := buffer.get_utf8_string()
		var id := varuint.decode(buffer) as int

		ids[full_name] = id

	return ids
