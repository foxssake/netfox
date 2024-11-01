extends Node

enum Role { NONE, HOST, CLIENT }

@export_category("UI")
@export var connect_ui: Control
@export var noray_address_input: LineEdit
@export var oid_input: LineEdit
@export var host_oid_input: LineEdit
@export var force_relay_check: CheckBox

@onready var brawler_spawner := %"Brawler Spawner" as BrawlerSpawner

var role = Role.NONE

func _ready():
	Noray.on_oid.connect(func(oid): oid_input.text = oid)
	Noray.on_connect_nat.connect(_handle_connect_nat)
	Noray.on_connect_relay.connect(_handle_connect_relay)

func connect_to_noray():
	# Connect to noray
	var err = OK
	var address = noray_address_input.text
	if address.contains(":"):
		var parts = address.split(":")
		var host = parts[0]
		var port = (parts[1] as String).to_int()
		err = await Noray.connect_to_host(host, port)
	else:
		err = await Noray.connect_to_host(address)
	
	if err != OK:
		print("Failed to connect to Noray: %s" % error_string(err))
		return err
	
	# Get IDs
	Noray.register_host()
	await Noray.on_pid
	
	# Register remote address
	err = await Noray.register_remote()
	if err != OK:
		print("Failed to register remote address: %s" % error_string(err))
		return err
	
	# Our local port is a remote port to Noray, hence the weird naming
	print("Registered local port: %d" % Noray.local_port)
	return OK

func disconnect_from_noray():
	Noray.disconnect_from_host()
	oid_input.clear()

func host_only():
	brawler_spawner.spawn_host_avatar = false
	host()

func host():
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
	
	role = Role.HOST
	connect_ui.hide()
	# NOTE: This is not needed when using NetworkEvents
	# However, this script also runs in multiplayer-simple where NetworkEvents
	# are assumed to be absent, hence starting NetworkTime manually
	NetworkTime.start()

func join():
	role = Role.CLIENT

	if force_relay_check.button_pressed:
		Noray.connect_relay(host_oid_input.text)
	else:
		Noray.connect_nat(host_oid_input.text)

func _handle_connect_nat(address: String, port: int) -> Error:
	var err = await _handle_connect(address, port)

	# If client failed to connect over NAT, try again over relay
	if err != OK and role != Role.HOST:
		print("NAT connect failed with reason %s, retrying with relay" % error_string(err))
		Noray.connect_relay(host_oid_input.text)
		err = OK

	return err

func _handle_connect_relay(address: String, port: int) -> Error:
	return await _handle_connect(address, port)

func _handle_connect(address: String, port: int) -> Error:
	if not Noray.local_port:
		return ERR_UNCONFIGURED

	var err = OK
	
	if role == Role.NONE:
		push_warning("Refusing connection, not running as client nor host")
		err = ERR_UNAVAILABLE
	
	if role == Role.CLIENT:
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
		
		connect_ui.hide()
		# NOTE: This is not needed when using NetworkEvents
		# However, this script also runs in multiplayer-simple where NetworkEvents
		# are assumed to be absent, hence starting NetworkTime manually
		NetworkTime.start()

	if role == Role.HOST:
		# We should already have the connection configured, only thing to do is a handshake
		var peer = get_tree().get_multiplayer().multiplayer_peer as ENetMultiplayerPeer
		
		err = await PacketHandshake.over_enet(peer.host, address, port)
		
		if err != OK:
			print("Handshake to %s:%s failed: %s" % [address, port, error_string(err)])
			return err
		print("Handshake to %s:%s concluded" % [address, port])

	return err
