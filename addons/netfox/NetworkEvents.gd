extends Node

signal on_multiplayer_change(old: MultiplayerAPI, new: MultiplayerAPI)

signal on_server_start
signal on_server_stop
signal on_client_start(id: int)
signal on_client_stop
signal on_peer_join(id: int)
signal on_peer_leave(id: int)

var enabled: bool:
	get: return _enabled
	set(v): _set_enabled(v)

var _is_server: bool = false
var _multiplayer: MultiplayerAPI
var _enabled = false

func is_server() -> bool:
	if multiplayer == null:
		return false
	
	var peer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	
	if peer is OfflineMultiplayerPeer:
		return false
		
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	
	if not multiplayer.is_server():
		return false
	
	return true

func _ready():
	enabled = ProjectSettings.get_setting("netfox/events/enabled", true)
	print("Network Events is %s" % [enabled])

	# Automatically start ticking when entering multiplayer and stop when 
	# leaving multiplayer
	on_server_start.connect(NetworkTime.start)
	on_server_stop.connect(NetworkTime.stop)
	on_client_start.connect(func(id): NetworkTime.start())
	on_client_stop.connect(NetworkTime.stop)

func _process(_delta):
	if multiplayer != _multiplayer:
		_disconnect_handlers(_multiplayer)
		_connect_handlers(multiplayer)
		
		on_multiplayer_change.emit(_multiplayer, multiplayer)
		_multiplayer = multiplayer
	
	if not _is_server and is_server():
		_is_server = true
		on_server_start.emit()
	
	if _is_server and not is_server():
		_is_server = false
		on_server_stop.emit()

func _connect_handlers(mp: MultiplayerAPI):
	if mp == null:
		return

	mp.connected_to_server.connect(_handle_connected_to_server)
	mp.server_disconnected.connect(_handle_server_disconnected)
	mp.peer_connected.connect(_handle_peer_connected)
	mp.peer_disconnected.connect(_handle_peer_disconnected)

func _disconnect_handlers(mp: MultiplayerAPI):
	if mp == null:
		return

	mp.connected_to_server.disconnect(_handle_connected_to_server)
	mp.server_disconnected.disconnect(_handle_server_disconnected)
	mp.peer_connected.disconnect(_handle_peer_connected)
	mp.peer_disconnected.disconnect(_handle_peer_disconnected)

func _handle_connected_to_server():
	on_client_start.emit(multiplayer.get_unique_id())

func _handle_server_disconnected():
	on_client_stop.emit()

func _handle_peer_connected(id: int):
	on_peer_join.emit(id)

func _handle_peer_disconnected(id: int):
	on_peer_leave.emit(id)

func _set_enabled(enable: bool):
	if _enabled and not enable:
		_disconnect_handlers(_multiplayer)
		_multiplayer = null
	if not _enabled and enable:
		_multiplayer = multiplayer
		_connect_handlers(_multiplayer)

	_enabled = enable
	set_process(enable)
