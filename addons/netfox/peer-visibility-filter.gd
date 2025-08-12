extends Node
class_name _PeerVisibilityFilter

var default_visibility: bool = true
var visibility_update_mode: int = 0 # TODO: Enum, cache visible peers?

var _visibility_filters: Array[Callable] = []
var _visibility_overrides: Dictionary = {}

var _visible_peers: Array[int] = []
var _iter_idx: int = -1

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
	_visible_peers.clear()
	for peer in peers:
		if get_visibility_for(peer):
			_visible_peers.append(peer)

func get_visible_peers() -> Array[int]:
	return _visible_peers

func _iter_init(arg) -> bool:
	update_visibility()

	_iter_idx = 0
	return _can_iterate()

func _iter_next(arg) -> bool:
	_iter_idx += 1
	return _can_iterate()

func _iter_get(arg):
	return _visible_peers[_iter_idx]

func _can_iterate() -> bool:
	if _visible_peers.is_empty() or _iter_idx >= _visible_peers.size():
		_iter_idx = -1
		return false
	return true
