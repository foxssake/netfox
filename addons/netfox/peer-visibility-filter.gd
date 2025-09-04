extends Node
class_name _PeerVisibilityFilter

enum UpdateMode {
	NEVER,
	ON_PEER,
	PER_TICK_LOOP,
	PER_TICK,
	PER_ROLLBACK_TICK
}

var default_visibility: bool = true
var update_mode: UpdateMode:
	get = get_update_mode, set = set_update_mode

var _visibility_filters: Array[Callable] = []
var _visibility_overrides: Dictionary = {}
var _update_mode: UpdateMode = UpdateMode.ON_PEER

var _visible_peers: Array[int] = []
var _rpc_target_peers: Array[int] = []

func add_visibility_filter(filter: Callable) -> void:
	if not _visibility_filters.has(filter):
		_visibility_filters.append(filter)

func remove_visibility_filter(filter: Callable) -> void:
	_visibility_filters.erase(filter)

func clear_visibility_filters() -> void:
	_visibility_filters.clear()

func get_visibility_for(peer: int) -> bool:
	for filter in _visibility_filters:
		if not filter.call(peer):
			return false
	return _visibility_overrides.get(peer, default_visibility)

func set_visibility_for(peer: int, visibility: bool) -> void:
	if peer == 0:
		default_visibility = visibility
	else:
		_visibility_overrides[peer] = visibility

func unset_visibility_for(peer: int) -> void:
	_visibility_overrides.erase(peer)

func update_visibility(peers: Array[int] = multiplayer.get_peers()) -> void:
	# Find visible peers
	_visible_peers.clear()
	for peer in peers:
		if get_visibility_for(peer):
			_visible_peers.append(peer)

	# Decide how many RPC calls are needed to cover visible peers
	if _visible_peers.size() == peers.size():
		# Everyone is visible -> broadcast
		_rpc_target_peers = [MultiplayerPeer.TARGET_PEER_BROADCAST]
	elif _visible_peers.size() == peers.size() - 1:
		# Only a single peer is missing, exclude that
		var excluded_peer := -1
		for peer in peers:
			if not _visible_peers.has(peer):
				_rpc_target_peers = [-peer]
				break
	else:
		# Custom list, can't optimize RPC call count
		_rpc_target_peers = _visible_peers
		# Don't include self in RPC target list
		# TODO: Make this configurable via flag
		_rpc_target_peers.erase(multiplayer.get_unique_id())

func get_visible_peers() -> Array[int]:
	return _visible_peers

func get_rpc_target_peers() -> Array[int]:
	return _rpc_target_peers

func set_update_mode(mode: UpdateMode) -> void:
	_disconnect_update_handlers(_update_mode)
	_connect_update_handlers(mode)
	_update_mode = mode

func get_update_mode() -> UpdateMode:
	return UpdateMode.NEVER

func _disconnect_update_handlers(mode: UpdateMode) -> void:
	match mode:
		UpdateMode.NEVER: pass
		UpdateMode.ON_PEER:
			multiplayer.peer_connected.disconnect(_handle_peer_connect)
			multiplayer.peer_disconnected.disconnect(_handle_peer_disconnect)
		UpdateMode.PER_TICK_LOOP:
			NetworkTime.before_tick_loop.disconnect(update_visibility)
		UpdateMode.PER_TICK:
			NetworkTime.before_tick.disconnect(_handle_tick)
		UpdateMode.PER_ROLLBACK_TICK:
			NetworkRollback.after_process_tick.disconnect(_handle_rollback_tick)
		_:
			assert(false, "Unhandled update mode! %d" % [update_mode])

func _connect_update_handlers(mode: UpdateMode) -> void:
	match mode:
		UpdateMode.NEVER: pass
		UpdateMode.ON_PEER:
			multiplayer.peer_connected.connect(_handle_peer_connect)
			multiplayer.peer_disconnected.connect(_handle_peer_disconnect)
		UpdateMode.PER_TICK_LOOP:
			NetworkTime.before_tick_loop.connect(update_visibility)
		UpdateMode.PER_TICK:
			NetworkTime.before_tick.connect(_handle_tick)
		UpdateMode.PER_ROLLBACK_TICK:
			NetworkRollback.after_process_tick.connect(_handle_rollback_tick)
		_:
			assert(false, "Unhandled update mode! %d" % [update_mode])

func _handle_peer_connect(__) -> void:
	update_visibility()

func _handle_peer_disconnect(__) -> void:
	update_visibility()

func _handle_tick(_dt, _t) -> void:
	update_visibility()

func _handle_rollback_tick(__) -> void:
	update_visibility()
