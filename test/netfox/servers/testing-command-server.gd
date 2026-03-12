extends _NetworkCommandServer
class_name TestingCommandServer

var commands_sent := [] as Array[Array]

func send_command(idx: int, data: PackedByteArray, target_peer: int = 0, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> void:
	commands_sent.append([idx, data, target_peer, mode, channel])
