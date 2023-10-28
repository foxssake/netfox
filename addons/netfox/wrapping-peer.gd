extends MultiplayerPeerExtension
class_name WrappingPeer

var _peer: MultiplayerPeer

func _init(peer: MultiplayerPeer):
	_peer = peer

func _get_connection_status ( ):
	return _peer.get_connection_status()

func _get_max_packet_size ( ):
	# TODO
	return 1024

func _get_packet_channel ( ):
	return _peer.get_packet_channel()

func _get_packet_mode ( ):
	return _peer.get_packet_mode()

func _get_packet_peer ( ):
	return _peer.get_packet_peer()

func _get_packet_script ( ):
	return _peer.get_packet()

func _get_transfer_channel ( ):
	return _peer.transfer_channel

func _get_transfer_mode ( ):
	return _peer.transfer_mode

func _get_unique_id ( ):
	return _peer.get_unique_id()

func _is_refusing_new_connections ( ):
	return _peer.refuse_new_connections

func _is_server ( ):
	# TODO
	return false

func _is_server_relay_supported ( ):
	return _peer.is_server_relay_supported()

func _poll ( ):
	_peer.poll()

func _put_packet_script ( p_buffer: PackedByteArray ):
	return _peer.put_packet(p_buffer)

func _set_refuse_new_connections ( p_enable: bool ):
	_peer.refuse_new_connections = p_enable

func _set_target_peer ( p_peer: int ):
	_peer.set_target_peer(p_peer)

func _set_transfer_channel ( p_channel: int ):
	_peer.transfer_channel = p_channel

func _set_transfer_mode ( p_mode: TransferMode ):
	_peer.transfer_mode = p_mode
