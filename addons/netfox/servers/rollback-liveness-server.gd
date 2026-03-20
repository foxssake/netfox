extends Node
class_name _RollbackLivenessServer

## Tracks subject livenesses
##
## The game state may be rolled back to ticks where certain subjects didn't
## exist yet, while others have already been despawned. Liveness tracking is
## tracking whether a given subject was active and part of the game at any given
## tick.
## [br][br]
## Liveness is constrained to [i]an interval[/i] - the subject is spawned at a
## given tick, and then gets despawned at another. Once the subject is despawned
## it can't be spawned again.

# TODO: Merge into NetworkHistoryServer?

var _respawn_callback := {}
var _despawn_callback := {}
var _autofree_subjects := _Set.new()

var _spawn_tick := {}
var _despawn_tick := {}
var _applied_liveness := {}

func register(subject: Node, respawn_callback: Callable, despawn_callback: Callable, autofree: bool = true, spawn_tick: int = NetworkRollback.tick) -> void:
	_respawn_callback[subject] = respawn_callback
	_despawn_callback[subject] = despawn_callback

	if autofree:
		_autofree_subjects.add(subject)

	_applied_liveness[subject] = true
	spawn(subject)

func deregister(subject: Node) -> void:
	_respawn_callback.erase(subject)
	_despawn_callback.erase(subject)
	_autofree_subjects.erase(subject)
	_spawn_tick.erase(subject)
	_despawn_tick.erase(subject)

func is_alive(subject: Node, tick: int) -> bool:
	var spawn_at := _spawn_tick.get(subject, tick + 1) as int
	var despawn_at := _despawn_tick.get(subject, tick - 1) as int

	# NOTE: This will return live ON the despawn tick, and dead AFTER the
	# despawn tick. This is so the deactivating game logic can run in rollback.
	return tick >= spawn_at and tick <= despawn_at

func spawn(subject: Node, tick: int = NetworkRollback.tick) -> void:
	_spawn_tick[subject] = tick

func despawn(subject: Node, tick: int = NetworkRollback.tick) -> void:
	_despawn_tick[subject] = tick

func restore_liveness(tick: int) -> void:
	for subject in _subjects():
		var liveness := is_alive(subject, tick)
		if _applied_liveness[subject] != liveness:
			if liveness: _respawn_callback[subject].call()
			else: _despawn_callback[subject].call()
			_applied_liveness[subject] = liveness

func free_old_subjects(threshold_tick: int = NetworkRollback.history_start) -> void:
	var old_subjects := []
	for subject in _autofree_subjects:
		if _despawn_tick.get(subject, threshold_tick + 1) < threshold_tick:
			# Deregistering would modify _autofree_subjects, defer instead
			old_subjects.append(subject)

	for subject in old_subjects:
		subject.queue_free()
		deregister(subject)

func _subjects() -> Array:
	return _respawn_callback.keys()
