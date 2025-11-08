extends Node

## Network Simulator 
##
## Auto connects launched instances and simulates network conditions like
## latency and packet loss. To use simply add this node to your scene tree and
## hook up the signals.

## Signal emitted on the instance that successfully started a server.
## Can be used for custom initialization logic, e.g. automatic login during
## testing.
signal server_created

## Signal emitted on instances that successfully connected as a client.
## Can be used for custom initialization logic, e.g. automatic login during
## testing.
signal client_connected

## Enable to automatically host and connect on start
var enabled: bool = false
## Server listening address. Use [code]*[/code] for all interfaces, or
#3 [code]127.0.0.1[/code] for localhost.
var hostname: String = "127.0.0.1"

## Server port to listen on, UDP proxy will use port + 1 if simulating latency
## or packet loss
var server_port: int = 9999

## Use ENet's built-in range encoding for compression
var use_compression: bool = true

## Simulated latency in milliseconds. Total ping time will be double this value
## (to and from)
var latency_ms: int = 0
## Simulated packet loss percentage
var packet_loss_percent: float = 0.0

static var _logger: NetfoxLogger = NetfoxLogger._for_extras("NetworkSimulator")

var _enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()

# UDP proxy
var _proxy_thread: Thread
var _proxy_loop_enabled := true
var _udp_proxy_server: PacketPeerUDP
var _udp_proxy_port: int
var _rng_packet_loss: RandomNumberGenerator = RandomNumberGenerator.new()

# Connection tracking
var _client_peers: Dictionary = {} # port to PacketPeerUDP
var _client_to_server_queue: Array[QueueEntry] = []
var _server_to_client_queue: Array[QueueEntry] = []

class QueueEntry:
	var packet_data: PackedByteArray
	var queued_at: int
	var source_port: int # Which client port this came from
	
	func _init(packet: PackedByteArray, timestamp: int, port: int) -> void:
		self.packet_data = packet
		self.queued_at = timestamp
		self.source_port = port

func _ready() -> void:
	# Check if enabled
	if not OS.has_feature("editor"):
		_logger.debug("Running outside editor, disabling")
		return

	_load_project_settings()
	if not enabled:
		_logger.debug("Feature disabled")
		return

	for env_var in ["CI", "NETFOX_CI", "NETFOX_NO_AUTOCONNECT"]:
		if OS.get_environment(env_var) != "":
			_logger.debug("Environment variable %s set, disabling", [env_var])
			return

	await get_tree().process_frame
	_udp_proxy_port = server_port + 1

	var status = _try_and_host()
	if status == Error.ERR_CANT_CREATE:
		_try_and_join()
	elif status != OK:
		_logger.error("Autoconnect failed with error - %s", [error_string(status)])

	if use_compression:
		_enet_peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = _enet_peer

func _is_proxy_required() -> bool:
	return latency_ms > 0 or packet_loss_percent > 0.0

func _try_and_host() -> Error:
	var status = _enet_peer.create_server(server_port)
	if status == OK:
		if _is_proxy_required():
			_start_udp_proxy()
		server_created.emit()
		_logger.info("Server started on port %s", [server_port])
	return status

func _try_and_join() -> Error:
	var connect_port = server_port
	if _is_proxy_required():
		connect_port = _udp_proxy_port
	var status = _enet_peer.create_client(hostname, connect_port)
	if status == OK:
		client_connected.emit()
		_logger.info("Client connected to %s:%s", [hostname, connect_port])
	return status

# Starts a UDP proxy server to simulate network conditions
# This will listen on _udp_proxy_port and forward packets to the server_port
# Runs on its own thread to avoid blocking the main thread
func _start_udp_proxy() -> void:
	_proxy_thread = Thread.new()
	_udp_proxy_server = PacketPeerUDP.new()

	var bind_status = _udp_proxy_server.bind(_udp_proxy_port, hostname)
	if bind_status != OK:
		_logger.error("Failed to bind UDP proxy port: ", bind_status)
		return

	_proxy_thread.start(_process_loop)

func _process_packets() -> void:
	var current_time: int = Time.get_ticks_msec()
	var send_threshold: int = current_time - latency_ms

	_read_client_to_server_packets(current_time)
	_process_client_to_server_packets(send_threshold)

	if not _client_peers.is_empty():
		_read_server_to_client_packets(current_time)
		_process_server_to_client_queue(send_threshold)

func _process_loop():
	while _proxy_loop_enabled:
		_process_packets()
		OS.delay_msec(1)

func _load_project_settings() -> void:
	enabled = ProjectSettings.get_setting(&"netfox/autoconnect/enabled", false)
	hostname = ProjectSettings.get_setting(&"netfox/autoconnect/host", "127.0.0.1")
	server_port = ProjectSettings.get_setting(&"netfox/autoconnect/port", 9999)
	use_compression = ProjectSettings.get_setting(&"netfox/autoconnect/use_compression", false)
	latency_ms = ProjectSettings.get_setting(&"netfox/autoconnect/simulated_latency_ms", 0)
	packet_loss_percent = ProjectSettings.get_setting(&"netfox/autoconnect/simulated_packet_loss_chance", 0.0)

func _is_data_available() -> bool:
	if _udp_proxy_server.get_available_packet_count() > 0:
		return true
	
	if not _client_to_server_queue.is_empty() or not _server_to_client_queue.is_empty():
		return true
	
	# Check if any client peers have packets waiting
	for client_peer in _client_peers.values():
		if client_peer.get_available_packet_count() > 0:
			return true
	
	return false

func _read_client_to_server_packets(current_time: int) -> void:
	while _udp_proxy_server.get_available_packet_count() > 0:
		var packet = _udp_proxy_server.get_packet()
		var err = _udp_proxy_server.get_packet_error()
		
		if err != OK:
			_logger.error("UDP proxy incoming packet error: ", err)
			continue
		
		var from_port = _udp_proxy_server.get_packet_port()
		_register_client_if_new(from_port)
		
		_client_to_server_queue.push_back(QueueEntry.new(packet, current_time, from_port))

func _register_client_if_new(port: int) -> void:
	if _client_peers.has(port):
		return

	# Create a dedicated peer for this client
	var client_peer = PacketPeerUDP.new()
	client_peer.set_dest_address(hostname, server_port)
	_client_peers[port] = client_peer

func _process_client_to_server_packets(send_threshold: int) -> void:
	var packets_to_keep: Array[QueueEntry] = []
	
	for entry in _client_to_server_queue:
		if send_threshold < entry.queued_at:
			packets_to_keep.append(entry)
		else:
			if _should_send_packet():
				var peer = _client_peers[entry.source_port] as PacketPeerUDP
				peer.put_packet(entry.packet_data)
	
	_client_to_server_queue = packets_to_keep

func _read_server_to_client_packets(current_time: int) -> void:
	for client_port in _client_peers.keys():
		var client_peer = _client_peers[client_port] as PacketPeerUDP
		
		while client_peer.get_available_packet_count() > 0:
			var packet = client_peer.get_packet()
			var err = client_peer.get_packet_error()
			
			if err != OK:
				_logger.error("UDP proxy server-to-client packet error from port %s : %s", [client_port, err])
				continue
			
			_server_to_client_queue.push_back(QueueEntry.new(packet, current_time, client_port))

func _process_server_to_client_queue(send_threshold: int) -> void:
	var packets_to_keep: Array[QueueEntry] = []
	
	for entry in _server_to_client_queue:
		if send_threshold < entry.queued_at:
			packets_to_keep.append(entry)
		else:
			if _should_send_packet():
				_udp_proxy_server.set_dest_address(hostname, entry.source_port)
				_udp_proxy_server.put_packet(entry.packet_data)
	
	_server_to_client_queue = packets_to_keep

# Send packet or simulate loss
func _should_send_packet() -> bool:
	return packet_loss_percent <= 0.0 or _rng_packet_loss.randf() >= (packet_loss_percent / 100.0)

func _exit_tree() -> void:
	if _proxy_thread and _proxy_thread.is_started():
		_proxy_loop_enabled = false
		_proxy_thread.wait_to_finish()
