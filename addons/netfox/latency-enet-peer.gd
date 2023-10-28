extends WrappingPeer
class_name LatencyENetPeer

var _enet: ENetMultiplayerPeer:
	get:
		return _peer as ENetMultiplayerPeer
	set(v):
		_peer = v

var _enet_is_server: bool = false

func _is_server():
	return _enet_is_server

func add_mesh_peer (peer_id: int, host: ENetConnection) -> Error:
	return _enet.add_mesh_peer(peer_id, host)

func create_client (address: String ,port: int, channel_count: int=0, in_bandwidth: int=0, out_bandwidth: int=0, local_port: int=0) -> Error:
	return _enet.create_client(address, port, channel_count, in_bandwidth, out_bandwidth, local_port)

func create_mesh (unique_id: int) -> Error:
	return _enet.create_mesh(unique_id)

func create_server (port: int, max_clients: int=32, max_channels: int=0, in_bandwidth: int=0, out_bandwidth: int=0) -> Error:
	var err = _enet.create_server(port, max_clients, max_channels, in_bandwidth, out_bandwidth)
	
	if err == OK:
		_enet_is_server = true
		
	return err

func get_peer (id: int) -> ENetPacketPeer:
	return _enet.get_peer(id)
