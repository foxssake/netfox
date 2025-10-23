extends Node
class_name ForestBrawlConnector

class ServiceHosts:
	var name: String
	var noray_address: String
	var nohub_address: String

	func _init(p_name: String, p_noray_address: String, p_nohub_address: String):
		name = p_name
		noray_address = p_noray_address
		nohub_address = p_nohub_address

const GAME_ID := "WK6koYfZ7cEMjcsba3ovxQF1lM9XjkWh"

static var known_service_hosts: Array[ServiceHosts] = [
	ServiceHosts.new("foxssake.studio", "foxssake.studio:8890", "foxssake.studio:12980"),
	ServiceHosts.new("localhost", "localhost:8890", "localhost:9980")
]

static var _instance: ForestBrawlConnector
static var _logger := _NetfoxLogger.new("forest-brawl", "ForestBrawlConnector")

var _noray_connector: ForestBrawlNorayConnector

var _noray_address := ""
var _nohub_address := ""

var _nohub_peer: StreamPeerTCP
var _nohub_client: NohubClient

var _hosted_lobby: NohubLobby

static func _static_init():
	known_service_hosts.make_read_only()

static func nohub() -> NohubClient:
	if not _instance: return null
	return _instance._nohub_client

static func noray_address() -> String:
	if not _instance: return ""
	return _instance._noray_address

static func nohub_address() -> String:
	if not _instance: return ""
	return _instance._nohub_address

static func connect_to_service_hosts(services: ServiceHosts) -> Error:
	return await connect_to_services(services.noray_address, services.nohub_address)

static func connect_to_any_service_host() -> Error:
	# TODO: Find one based on ping
	return await connect_to_service_hosts(known_service_hosts[0])

static func connect_to_services(p_noray_address: String, p_nohub_address: String) -> Error:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	return await _instance._connect_to_services(p_noray_address, p_nohub_address)

static func disconnect_from_services() -> void:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	_instance._disconnect_from_services()

static func is_connected_to_services() -> bool:
	if not _instance: return false
	return _instance._is_connected_to_services()

static func join(address: String) -> Error:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	return _instance._join(address)

static func join_noray(oid: String) -> Error:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	return _instance._join_noray(oid)

static func host_lobby(name: String, address: String, max_players: int = 8) -> NohubResult.Lobby:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	return await _instance._host_lobby(name, address, max_players)

static func host_quick_play(address: String, max_players: int = 8) -> NohubResult.Lobby:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	return await _instance._host_quick_play(address, max_players)

static func host_noray() -> Error:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	return await _instance._host_noray()

static func update_player_count(player_count: int) -> void:
	assert(_instance, "ForestBrawlConnector instance missing from Scene Tree!")
	await _instance._update_player_count(player_count)

func _connect_to_services(p_noray_address: String, p_nohub_address: String) -> Error:
	_disconnect_from_services()

	var noray_address = _parse_address(p_noray_address, 8890)
	var nohub_address = _parse_address(p_nohub_address, 12980)

	# Connect to noray
	_logger.info("Connecting to noray at %s:%d...", [noray_address[0], noray_address[1]])
	var err := await Noray.connect_to_host(noray_address[0], noray_address[1])
	if err != OK:
		_logger.info("Failed to connect to noray: %s" % [error_string(err)])
		_disconnect_from_services()
		return err
	_logger.info("Successfully connected to noray!")

	# Connect to nohub
	_logger.info("Connecting to nohub at %s:%d...", [noray_address[0], noray_address[1]])
	var peer := StreamPeerTCP.new()
	peer.connect_to_host(nohub_address[0], nohub_address[1])
	while true:
		peer.poll()
		match peer.get_status():
			StreamPeerTCP.STATUS_CONNECTED:
				_logger.info("Successfully connected to nohub!")
				break
			StreamPeerTCP.STATUS_ERROR:
				_logger.info("Failed to connect to nohub!")
				_disconnect_from_services()
				return ERR_CONNECTION_ERROR
		await get_tree().process_frame

	_nohub_peer = peer
	_nohub_client = NohubClient.new(peer)

	# Register with noray
	_logger.info("Registering host with noray... ")
	Noray.register_host()
	await Noray.on_pid
	_logger.info("Success!")

	_logger.info("Registering remote with noray... ")
	err = await Noray.register_remote()
	if err != OK:
		_logger.info("Failed registering remote address: %s" % error_string(err))
		_disconnect_from_services()
		return ERR_CANT_ACQUIRE_RESOURCE
	_logger.info("Success!")

	# Set GameID in nohub
	_logger.info("Setting game ID with nohub... ")
	await get_tree().process_frame
	var response := await _nohub_client.set_game(GAME_ID)
	if not response.is_success():
		_logger.info("Failed to set game ID! %s" % [response])
		_disconnect_from_services()
		return ERR_QUERY_FAILED
	_logger.info("Success!")

	# Success
	_noray_address = "%s:%d" % noray_address
	_nohub_address = "%s:%d" % nohub_address

	return OK

func _disconnect_from_services() -> void:
	_hosted_lobby = null

	if Noray.is_connected_to_host():
		Noray.disconnect_from_host()
		_noray_address = ""

	if _nohub_peer != null:
		_nohub_peer.disconnect_from_host()
		_nohub_peer = null
		_nohub_client = null
		_nohub_address = ""

func _is_connected_to_services() -> bool:
	return Noray.is_connected_to_host() and _nohub_peer != null and _nohub_peer.get_status() == StreamPeerTCP.STATUS_CONNECTED

func _join(address: String) -> Error:
	var uri := _parse_uri(address)
	if uri.is_empty():
		_logger.info("Failed to parse URI: %s", [address])
		return ERR_PARSE_ERROR
	
	if uri["protocol"] == "noray":
		# TODO: Support different hosts
		var oid := uri["path"] as String
		return _join_noray(oid)
	
	_logger.info("Unknown schema: %s" % [uri["protocol"]])
	return ERR_UNAVAILABLE

func _join_noray(oid: String) -> Error:
	return _noray_connector.join(oid)

func _host_lobby(name: String, address: String, max_players: int = 8, extra_data: Dictionary = {}) -> NohubResult.Lobby:
	if not _nohub_client:
		return NohubResult.of_error("NotConnectedError", "No nohub client present!")

	# TODO(nohub.gd): Stringify data values
	var base_data := { "name": name, "player-count": "0", "player-capacity": str(max_players) }
	var data := extra_data.duplicate()
	data.merge(base_data, true)

	var response := await _nohub_client.create_lobby(address, data)
	if response.is_success():
		_hosted_lobby = response.value()
	return response

func _host_quick_play(address: String, max_players: int = 8) -> NohubResult.Lobby:
	var name := "Quick Play #%x" % [randi_range(0x10000000, 0xFFFFFFFF)]
	return await _host_lobby(name, address, max_players, { "quick-play": "enabled" })

func _host_noray() -> Error:
	return await _noray_connector.host()

func _update_player_count(player_count: int) -> void:
	if not _nohub_client:
		return
	if not _hosted_lobby:
		return

	_hosted_lobby.data["player-count"] = str(player_count)
	await _nohub_client.set_lobby_data(_hosted_lobby.id, _hosted_lobby.data)

func _report_player_count() -> void:
	if multiplayer.is_server():
		_update_player_count(multiplayer.get_peers().size() + 1)

func _ready():
	_instance = self
	_noray_connector = ForestBrawlNorayConnector.new()
	add_child(_noray_connector)

	NetworkEvents.on_peer_join.connect(func(__): _report_player_count())
	NetworkEvents.on_peer_leave.connect(func(__): _report_player_count())
	NetworkEvents.on_server_start.connect(func(): _report_player_count())
	NetworkEvents.on_server_stop.connect(func():
		if _hosted_lobby and _nohub_client:
			await _nohub_client.delete_lobby(_hosted_lobby.id)
			_hosted_lobby = null
	)

func _process(_dt) -> void:
	if _nohub_peer:
		var err := _nohub_peer.poll()
		if err != OK:
			_logger.info("Failed polling nohub: %s", [error_string(err)])
			_disconnect_from_services()

	if _nohub_client:
		# TODO(trimsock): Return poll result, so we don't need to poll the peer separately
		_nohub_client.poll()

func _parse_address(address: String, default_port: int = 0) -> Array:
	var result = ["", default_port]
	if address.contains(":"):
		var idx := address.rfind(":")
		result[0] = address.substr(0, idx)
		result[1] = int(address.substr(idx + 1))
	else:
		result[0] = address
	return result

func _parse_uri(uri: String) -> Dictionary:
	var pattern := RegEx.create_from_string("([a-zA-Z0-9]+)://([^/:]+):?([0-9]+)?/(.*)")
	var hit := pattern.search(uri)
	if not hit: return {}

	return {
		"uri": uri,
		"protocol": hit.strings[1],
		"host": hit.strings[2],
		"port": hit.strings[3],
		"path": hit.strings[4]
	}
