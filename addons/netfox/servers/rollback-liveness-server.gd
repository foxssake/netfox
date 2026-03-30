extends Node
class_name _RollbackLivenessServer

# @public class

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

var _respawn_callback := {}
var _despawn_callback := {}
var _destroy_callback := {}

var _spawn_tick := {}
var _despawn_tick := {}
var _applied_liveness := {}

static var _logger := NetfoxLogger._for_netfox("RollbackLivenessServer")

## Register [param subject] for liveness tracking.
## [br][br]
## Whenever the subject needs to be (re)spawned or despawned,
## [param respawn_callback] and [param despawn_callback] will be called,
## respectively. Once it is sure that the subject won't be respawned,
## [param destroy_callback] will be called.
## [br][br]
## Note that any [Callable] can be used. This could be a method on the subject
## itself, or on any other object, e.g. a central orchestrator.
func register(subject: Node, respawn_callback: Callable, despawn_callback: Callable, destroy_callback: Callable = _free_subject.bind(subject), spawn_tick: int = NetworkRollback.tick) -> void:
	if is_registered(subject):
		_logger.warning("Re-registering subject: %s", [subject])
		return

	_respawn_callback[subject] = respawn_callback
	_despawn_callback[subject] = despawn_callback
	_destroy_callback[subject] = destroy_callback

	_applied_liveness[subject] = true
	spawn(subject, spawn_tick)

## Return true if [param subject] is registered for liveness tracking.
func is_registered(subject: Node) -> bool:
	return _has_subject(subject)

## Deregister [param subject] from liveness tracking.
## [br][br]
## Note that its liveness will not be updated - if the subject was despawned
## before being deregistered, it will not be respawned.
func deregister(subject: Node) -> void:
	_respawn_callback.erase(subject)
	_despawn_callback.erase(subject)
	_destroy_callback.erase(subject)
	_spawn_tick.erase(subject)
	_despawn_tick.erase(subject)

## Return true if [param subject] is alive at [param tick].
## [br][br]
## Unknown subjects will always be considered alive. [br]
## If a subject is despawned, it will only become dead on the next tick. This
## allows the despawn logic to run in rollback.
func is_alive(subject: Node, tick: int) -> bool:
	# Unknown subjects are always alive, don't despawn
	if not is_registered(subject): return true

	var spawn_at := _spawn_tick.get(subject, tick + 1) as int
	var despawn_at := _despawn_tick.get(subject, tick + 1) as int

	# NOTE: This will return live ON the despawn tick, and dead AFTER the
	# despawn tick. This is so the deactivating game logic can run in rollback.
	return tick >= spawn_at and tick <= despawn_at

## Mark the [param subject]'s spawn at [param tick].
func spawn(subject: Node, tick: int = NetworkRollback.tick) -> void:
	_spawn_tick[subject] = tick

## Mark the [param subject]'s despawn at [param tick].
func despawn(subject: Node, tick: int = NetworkRollback.tick) -> void:
	if not is_registered(subject):
		_logger.warning(
			"Trying to despawn unknown subject: %s; " +
			"register it first using RollbackLivenessServer.register()",
			[subject]
		)
		return
	_despawn_tick[subject] = tick

## Clear any previously set despawn tick for [param subject].
func clear_despawn(subject: Node) -> void:
	_despawn_tick.erase(subject)

## Restore the liveness of all subjects as it was on [param tick].
func restore_liveness(tick: int) -> void:
	for subject in _subjects():
		var liveness := is_alive(subject, tick)
		if _applied_liveness[subject] != liveness:
			_logger.trace("Restoring %s to %s liveness ( @%s;@%s )", [subject, liveness, _spawn_tick.get(subject), _despawn_tick.get(subject)])
			if liveness: _respawn_callback[subject].call()
			else: _despawn_callback[subject].call()
			_applied_liveness[subject] = liveness

## Destroy all dead subjects that won't be respawned.
## [br][br]
## [param threshold_tick] specifies the tick beyond which no rollback
## will occur. By default, this is [member _NetworkRollback.history_start],
## because no ticks before that will be resimulated.
func destroy_old_subjects(threshold_tick: int = NetworkRollback.history_start) -> void:
	var old_subjects := []
	for subject in _subjects():
		if _despawn_tick.get(subject, threshold_tick + 1) < threshold_tick:
			# Deregistering would modify _autofree_subjects, defer instead
			old_subjects.append(subject)

	for subject in old_subjects:
		_logger.trace("Freeing %s as too old ( despawned at @%d )", [subject, _despawn_tick[subject]])
		_destroy_callback[subject].call()
		deregister(subject)

func _subjects() -> Array:
	return _respawn_callback.keys()

func _has_subject(subject: Object) -> bool:
	return _respawn_callback.has(subject)

func _free_subject(subject: Node) -> void:
	subject.queue_free()
