extends Node

# TODO: Merge into NetworkHistoryServer?

var _respawn_callback := {}
var _despawn_callback := {}
var _autofree_subjects := _Set.new()

func register(subject: Node, respawn_callback: Callable, despawn_callback: Callable, autofree: bool = true) -> void:
	_respawn_callback[subject] = respawn_callback
	_despawn_callback[subject] = despawn_callback

	if autofree:
		_autofree_subjects.add(subject)

func deregister(subject: Node) -> void:
	_respawn_callback.erase(subject)
	_despawn_callback.erase(subject)
	_autofree_subjects.erase(subject)

func is_alive(subject: Node, tick: int) -> bool:
	return true

func set_liveness(subject: Node, tick: int, liveness: bool) -> void:
	pass

func restore_liveness(tick: int) -> void:
	pass

func free_old_subjects(threshold_tick: int = NetworkRollback.history_start) -> void:
	pass
