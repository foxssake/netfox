extends Node
class_name ForestBrawlNorayConnector

var _is_host := false
var _is_client := false
var _target_oid := ""

func _ready():
	Noray.on_connect_nat.connect(_handle_connect_nat)
	Noray.on_connect_relay.connect(_handle_connect_relay)

func host() -> Error:
	if Noray.local_port <= 0:
		return ERR_UNCONFIGURED
	
	# Start host
	var err = OK
	var port = Noray.local_port
	print("Starting host on port %s" % port)
	
	var peer = ENetMultiplayerPeer.new()
	err = peer.create_server(port)
	if err != OK:
		print("Failed to listen on port %s: %s" % [port, error_string(err)])
		return err

	get_tree().get_multiplayer().multiplayer_peer = peer
	print("Listening on port %s" % port)
	
	# Wait for server to start
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().process_frame
	
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		OS.alert("Failed to start server!")
		return FAILED
	
	get_tree().get_multiplayer().server_relay = true
	
	_is_host = true
	_is_client = false

	return OK

func join(oid: String, force_relay: bool = false) -> Error:
	_is_host = false
	_is_client = true
	_target_oid = oid

	if force_relay:
		return Noray.connect_relay(oid)
	else:
		return Noray.connect_nat(oid)

func _handle_connect_nat(address: String, port: int) -> Error:
	var err = await _handle_connect(address, port)

	# If client failed to connect over NAT, try again over relay
	if err != OK and not _is_host:
		print("NAT connect failed with reason %s, retrying with relay" % error_string(err))
		Noray.connect_relay(_target_oid)
		err = OK

	return err

func _handle_connect_relay(address: String, port: int) -> Error:
	return await _handle_connect(address, port)

func _handle_connect(address: String, port: int) -> Error:
	if not Noray.local_port:
		return ERR_UNCONFIGURED

	var err = OK
	
	if not _is_host and not _is_client:
		push_warning("Refusing connection, not running as client nor host")
		err = ERR_UNAVAILABLE
	
	if _is_client:
		var udp = PacketPeerUDP.new()
		udp.bind(Noray.local_port)
		udp.set_dest_address(address, port)
		
		print("Attempting handshake with %s:%s" % [address, port])
		err = await PacketHandshake.over_packet_peer(udp)
		udp.close()
		
		if err != OK:
			if err == ERR_BUSY:
				print("Handshake to %s:%s succeeded partially, attempting connection anyway" % [address, port])
			else:
				print("Handshake to %s:%s failed: %s" % [address, port, error_string(err)])
				return err
		else:
			print("Handshake to %s:%s succeeded" % [address, port])

		# Connect
		var peer = ENetMultiplayerPeer.new()
		err = peer.create_client(address, port, 0, 0, 0, Noray.local_port)
		if err != OK:
			print("Failed to create client: %s" % error_string(err))
			return err

		get_tree().get_multiplayer().multiplayer_peer = peer
		
		# Wait for connection to succeed
		await Async.condition(
			func(): return peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING
		)
			
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			print("Failed to connect to %s:%s with status %s" % [address, port, peer.get_connection_status()])
			get_tree().get_multiplayer().multiplayer_peer = null
			return ERR_CANT_CONNECT

	if _is_host:
		# We should already have the connection configured, only thing to do is a handshake
		var peer = get_tree().get_multiplayer().multiplayer_peer as ENetMultiplayerPeer
		
		err = await PacketHandshake.over_enet_peer(peer, address, port)
		
		if err != OK:
			print("Handshake to %s:%s failed: %s" % [address, port, error_string(err)])
			return err
		print("Handshake to %s:%s concluded" % [address, port])

	return err
