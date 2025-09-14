extends Node
class_name PeerVisibilityFilter

## Tracks visibility for multiplayer peers
##
## Similar in how [MultiplayerSynchronizer] handles visibility. It decides peer
## visibility based on individual overrides and filters.
## [br][br]
## By default, each peer's visibility is determined by
## [member default_visibility]. [br][br]
## The default visibility can be overridden for individual peers using 
## [method set_visibility_for] and [method unset_visibility_for].
## [br][br]
## Individual overrides can still be rejected by [i]filters[/i], which are
## callables that can dynamically determine the visibility for each peer. If any
## of the registered filters return [code]false[/code], the peer will not be
## visible. Filters can be managed using [member add_visibility_filter] and
## [member remove_visibility_filter].
## [br][br]
## To avoid taking up too much CPU time, visibilities are only recalculated on
## a peer join or peer leave event by default. This can be changed by setting 
## [member update_mode]. Visibilities can also be manually updated using
## [member update_visibility].

## Contains different options for when to automatically update visibility
enum UpdateMode {
	NEVER,				## Only update visibility when manually triggered
	ON_PEER,			## Update visibility when a peer joins or leaves
	PER_TICK_LOOP,		## Update visibility before each tick loop
	PER_TICK,			## Update visibility before each network tick
	PER_ROLLBACK_TICK	## Update visibility [b]after[/b] each rollback tick
}

## Make all peers visible by default if true
var default_visibility: bool = true
## Sets whether and when automatic visibility updates should happen
var update_mode: UpdateMode = UpdateMode.ON_PEER:
	get = get_update_mode, set = set_update_mode

var _visibility_filters: Array[Callable] = []
var _visibility_overrides: Dictionary = {}
var _update_mode: UpdateMode = UpdateMode.ON_PEER

var _visible_peers: Array[int] = []
var _rpc_target_peers: Array[int] = []

## Register a visibility filter
## [br][br]
## The [param filter] must take a single [code]peer_id[/code] parameter, and
## return true if the given peer should be visible. The same [param filter]
## won't be added multiple times.
func add_visibility_filter(filter: Callable) -> void:
	if not _visibility_filters.has(filter):
		_visibility_filters.append(filter)

## Remove a visibility filter
## [br][br]
## If the visibility filter wasn't already registered, nothing happens.
func remove_visibility_filter(filter: Callable) -> void:
	_visibility_filters.erase(filter)

## Remove all previously registered visibility filters
func clear_visibility_filters() -> void:
	_visibility_filters.clear()

## Return true if the peer is visible
## [br][br]
## This method always reevaluates visibility.
func get_visibility_for(peer: int) -> bool:
	for filter in _visibility_filters:
		if not filter.call(peer):
			return false
	return _visibility_overrides.get(peer, default_visibility)

## Set visibility override for a given [param peer]
func set_visibility_for(peer: int, visibility: bool) -> void:
	if peer == 0:
		default_visibility = visibility
	else:
		_visibility_overrides[peer] = visibility

## Remove visibility override for a given [param peer]
## [br][br]
## If the [param peer] had no override previously, nothing happens.
func unset_visibility_for(peer: int) -> void:
	_visibility_overrides.erase(peer)

## Recalculate visibility for each known peer
func update_visibility(peers: PackedInt32Array = multiplayer.get_peers()) -> void:
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
		for peer in peers:
			if not _visible_peers.has(peer):
				_rpc_target_peers = [-peer]
				break
	else:
		# Custom list, can't optimize RPC call count
		_rpc_target_peers = _visible_peers
		# Don't include self in RPC target list
		if multiplayer:
			_rpc_target_peers.erase(multiplayer.get_unique_id())

## Return a list of visible peers
## [br][br]
## This list is only recalculated when [method update_visibility] runs, either
## by calling it manually, or via [member update_mode].
func get_visible_peers() -> Array[int]:
	return _visible_peers

## Return a list of visible peers for use with RPCs
## [br][br]
## In contrast to [method get_visible_peers], this method will utilize Godot's
## RPC target peer rules to produce a shorter list if possible. For example, if
## all peers are visible, it will simply return [code][0][/code], indicating
## a broadcast.
## [br][br]
## This list will never explicitly include the local peer.
func get_rpc_target_peers() -> Array[int]:
	return _rpc_target_peers

## Set update mode
func set_update_mode(mode: UpdateMode) -> void:
	_disconnect_update_handlers(_update_mode)
	_connect_update_handlers(mode)
	_update_mode = mode

## Return the update mode
func get_update_mode() -> UpdateMode:
	return _update_mode

func _enter_tree():
	_connect_update_handlers(update_mode)
	if multiplayer:
		update_visibility()

func _exit_tree():
	_disconnect_update_handlers(update_mode)

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
