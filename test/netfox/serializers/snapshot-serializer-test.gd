extends VestTest
class_name SnapshotSerializerTest

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func to_buffer(data: PackedByteArray) -> StreamPeerBuffer:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	return buffer
