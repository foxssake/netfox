extends Node

class_name NetworkSimulator

## Network Simulator 
## Auto connects launched instances and simulates network conditions like latency and packet loss

## Signal emitted on instance that successfully started a server
## Initialize your server from this signal
signal server_created

## Signal emitted on instance that successfully connected as a client
## Initialize your clients from this signal
signal client_connected

@export_category("Server")
## Server listening address. 127.0.0.1 for localhost, use * for all interfaces.
@export var hostname: String = "127.0.0.1"

## Server port to listen on, udp proxy will use port + 1 if simulating latency or packet loss
@export var server_port: int = 9999

## Use ENet's built-in range encoding for compression
@export var use_compression: bool = true

@export_category("Network Settings")
## Simulated latency in milliseconds. Total ping time will be double this value (to and from).
@export_range(0, 200) var latency_ms: int = 0
## Simulated packet loss percentage
@export_range(0, 100) var packet_loss_percent: float = 0.0

static var _logger: _NetfoxLogger = _NetfoxLogger.for_extras("NetworkSimulator")

var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

# UDP proxy
var proxy_thread: Thread
var udp_proxy_server: PacketPeerUDP
var udp_proxy_port: int
var rng_packet_loss: RandomNumberGenerator = RandomNumberGenerator.new()

# Connection tracking
var client_peers: Dictionary = {} # port to PacketPeerUDP
var client_to_server_queue: Array[QueueEntry] = []
var server_to_client_queue: Array[QueueEntry] = []

class QueueEntry:
	var packet_data: PackedByteArray
	var queued_at: int
	var source_port: int # Which client port this came from
	
	func _init(packet: PackedByteArray, timestamp: int, port: int) -> void:
		self.packet_data = packet
		self.queued_at = timestamp
		self.source_port = port

func _ready() -> void:
	await get_tree().process_frame
	udp_proxy_port = server_port + 1
	
	if OS.has_feature("editor"):
		var status = try_and_host()
		if status == Error.ERR_CANT_CREATE:
			try_and_join()
		elif status != OK:
			_logger.error("Auto connecting failed with error - %s", [error_string(status)])


		if use_compression:
			enet_peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)

		multiplayer.multiplayer_peer = enet_peer

func try_and_host() -> Error:
	var status = enet_peer.create_server(server_port)
	if status == OK:
		if is_proxy_required():
			start_udp_proxy()
		server_created.emit()
		_logger.info("Server started on port %s", [server_port])
	return status

func try_and_join() -> Error:
	var connect_port = server_port
	if is_proxy_required():
		connect_port = udp_proxy_port
	var status = enet_peer.create_client(hostname, connect_port)
	if status == OK:
		client_connected.emit()
		_logger.info("Client connected to %s:%s", [hostname, connect_port])
	return status

# Starts a UDP proxy server to simulate network conditions
# This will listen on udp_proxy_port and forward packets to the server_port
# Runs on its own thread to avoid blocking the main thread
func start_udp_proxy() -> void:
	proxy_thread = Thread.new()
	udp_proxy_server = PacketPeerUDP.new()
	
	var bind_status = udp_proxy_server.bind(udp_proxy_port, hostname)
	if bind_status != OK:
		_logger.error("Failed to bind UDP proxy port: ", bind_status)
		return
	
	proxy_thread.start(process_packets)


func process_packets() -> void:
	while true:
		var wait_backoff: int = 1
		while not _is_data_available():
			OS.delay_msec(wait_backoff)
			wait_backoff = clamp(wait_backoff + 1, 1, 10)

		var current_time: int = Time.get_ticks_msec()
		var send_threshold: int = current_time - latency_ms
		
		_read_client_to_server_packets(current_time)
		_process_client_to_server_packets(send_threshold)

		if not client_peers.is_empty():
			_read_server_to_client_packets(current_time)
			_process_server_to_client_queue(send_threshold)

func _is_data_available() -> bool:
	if udp_proxy_server.get_available_packet_count() > 0:
		return true
	
	if not client_to_server_queue.is_empty() or not server_to_client_queue.is_empty():
		return true
	
	# Check if any client peers have packets waiting
	for client_peer in client_peers.values():
		if client_peer.get_available_packet_count() > 0:
			return true
	
	return false

func _read_client_to_server_packets(current_time: int) -> void:
	while udp_proxy_server.get_available_packet_count() > 0:
		var packet = udp_proxy_server.get_packet()
		var err = udp_proxy_server.get_packet_error()
		
		if err != OK:
			_logger.error("UDP proxy incoming packet error: ", err)
			continue
		
		var from_port = udp_proxy_server.get_packet_port()
		_register_client_if_new(from_port)
		
		client_to_server_queue.push_back(QueueEntry.new(packet, current_time, from_port))

func _register_client_if_new(port: int) -> void:
	if client_peers.has(port):
		return

	# Create a dedicated peer for this client
	var client_peer = PacketPeerUDP.new()
	client_peer.set_dest_address(hostname, server_port)
	client_peers[port] = client_peer

func _process_client_to_server_packets(send_threshold: int) -> void:
	var packets_to_keep: Array[QueueEntry] = []
	
	for entry in client_to_server_queue:
		if send_threshold < entry.queued_at:
			packets_to_keep.append(entry)
		else:
			if _should_send_packet():
				var peer = client_peers[entry.source_port] as PacketPeerUDP
				peer.put_packet(entry.packet_data)
	
	client_to_server_queue = packets_to_keep

func _read_server_to_client_packets(current_time: int) -> void:
	for client_port in client_peers.keys():
		var client_peer = client_peers[client_port] as PacketPeerUDP
		
		while client_peer.get_available_packet_count() > 0:
			var packet = client_peer.get_packet()
			var err = client_peer.get_packet_error()
			
			if err != OK:
				_logger.error("UDP proxy server-to-client packet error from port %s : %s", [client_port, err])
				continue
			
			server_to_client_queue.push_back(QueueEntry.new(packet, current_time, client_port))

func _process_server_to_client_queue(send_threshold: int) -> void:
	var packets_to_keep: Array[QueueEntry] = []
	
	for entry in server_to_client_queue:
		if send_threshold < entry.queued_at:
			packets_to_keep.append(entry)
		else:
			if _should_send_packet():
				udp_proxy_server.set_dest_address(hostname, entry.source_port)
				udp_proxy_server.put_packet(entry.packet_data)
	
	server_to_client_queue = packets_to_keep

# Send packet or simulate loss
func _should_send_packet() -> bool:
	return packet_loss_percent <= 0.0 or rng_packet_loss.randf() >= (packet_loss_percent / 100.0)

func is_proxy_required() -> bool:
	return latency_ms > 0 or packet_loss_percent > 0.0

func _exit_tree() -> void:
	if proxy_thread and proxy_thread.is_started():
		proxy_thread.wait_to_finish()
