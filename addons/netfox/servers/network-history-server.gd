extends Node
class_name _NetworkHistoryServer

## Tracks the history of objects' properties
##
## Specifically, history is stored for rollback state properties, rollback input
## properties, and synchronized state properties.
## [br][br]
## Keeping history lets rollback restore earlier game states for resimulation,
## and enables [_NetworkSynchronizationServer] to send diff states by comparing
## against historical data.

var _rb_input_properties := _PropertyPool.new()
var _rb_state_properties := _PropertyPool.new()
var _sync_state_properties := _PropertyPool.new()

var _rb_history_size := NetworkRollback.history_limit
var _sync_history_size := ProjectSettings.get_setting("netfox/state_synchronizer/history_limit", 64) as int

# Source of truth for history
var _rb_input_history := _PerObjectHistory.new(_rb_history_size)
var _rb_state_history := _PerObjectHistory.new(_rb_history_size)
var _sync_history := _PerObjectHistory.new(_sync_history_size)

# Cached snapshots for syncing
var _rb_input_snapshots := _HistoryBuffer.new(_rb_history_size)
var _rb_state_snapshots := _HistoryBuffer.new(_rb_history_size)
var _sync_state_snapshots := _HistoryBuffer.new(_sync_history_size)

static var _logger := NetfoxLogger._for_netfox("NetworkHistoryServer")

## Register a rollback state property
func register_rollback_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.add(node, property)

## Deregister a rollback state property
func deregister_rollback_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.erase(node, property)

## Register a rollback input property
func register_rollback_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.add(node, property)

## Deregister a rollback input property
func deregister_rollback_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.erase(node, property)

## Register a synchronized state property
func register_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.add(node, property)

## Deregister a synchronized state property
func deregister_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.erase(node, property)

## Deregister a node, no longer tracking any property it had registered using
## any of the [code]register_*()[/code] methods
func deregister(node: Node) -> void:
	_rb_state_properties.erase_subject(node)
	_rb_input_properties.erase_subject(node)
	_sync_state_properties.erase_subject(node)

	_rb_state_history.erase_subject(node)
	_rb_input_history.erase_subject(node)
	_sync_history.erase_subject(node)

## Return the latest tick where any of the [param]subjects[/param] had rollback
## state data available
func get_latest_state_tick_for(subjects: Array, tick: int) -> int:
	return _get_latest_for(subjects, tick, _rb_state_history)

## Return how old is the latest rollback state data for any of the [param]
## subjects[/param], in ticks
func get_state_age_for(subjects: Array, tick: int) -> int:
	var latest_state := get_latest_state_tick_for(subjects, tick)
	if latest_state < 0:
		return -1
	else:
		return tick - latest_state

## Return the latest tick where any of the [param]subjects[/param] had rollback
## input data available
func get_latest_input_for(subjects: Array, tick: int) -> int:
	return _get_latest_for(subjects, tick, _rb_input_history)

## Return how old is the latest rollback input data for any of the [param]
## subjects[/param], in ticks
func get_input_age_for(subjects: Array, tick: int) -> int:
	var latest_input := get_latest_input_for(subjects, tick)
	if latest_input < 0:
		return -1
	else:
		return tick - latest_input

func _record_rollback_input(tick: int) -> void:
	_record(tick, _rb_input_history, _rb_input_snapshots, _rb_input_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

func _record_rollback_state(tick: int) -> void:
	var input_snapshot := _get_rollback_input_snapshot(tick - 1)

	_record(tick, _rb_state_history, _rb_state_snapshots, _rb_state_properties, false, func(subject: Node):
		if not subject.is_multiplayer_authority():
			return false
		if RollbackSimulationServer._is_predicting(input_snapshot, subject):
			return false
		return true
	)

func _record_sync_state(tick: int) -> void:
	_record(tick, _sync_history, _sync_state_snapshots, _sync_state_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

func _restore_rollback_input(tick: int) -> bool:
	return _restore_latest(tick, _rb_input_history)

func _restore_rollback_state(tick: int) -> bool:
	return _restore_latest(tick, _rb_state_history)

func _restore_synchronizer_state(tick: int) -> bool:
	return _restore_latest(tick, _sync_history)

func _get_rollback_input_snapshot(tick: int) -> _Snapshot:
	return _rb_input_snapshots.get_at(tick)

func _get_rollback_state_snapshot(tick: int) -> _Snapshot:
	return _rb_state_snapshots.get_at(tick)

func _get_synchronizer_state_snapshot(tick: int) -> _Snapshot:
	return _sync_state_snapshots.get_at(tick)

func _merge_rollback_input(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _rb_input_snapshots, true)
	return _merge_history(snapshot, _rb_input_history, true)

func _merge_rollback_state(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _rb_state_snapshots, true)
	return _merge_history(snapshot, _rb_state_history)

func _merge_synchronizer_state(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _sync_state_snapshots, true)
	return _merge_history(snapshot, _sync_history)

func _record(tick: int, history: _PerObjectHistory, snapshots: _HistoryBuffer, property_pool: _PropertyPool, only_auth: bool, auth_filter: Callable) -> void:
	var snapshot := snapshots.get_at(tick, _Snapshot.new(tick)) as _Snapshot
	if not snapshots.has_at(tick):
		snapshots.set_at(tick, snapshot)

	for subject in property_pool.get_subjects():
		assert(subject is Node, "Only nodes supported for now!")

		var is_auth := auth_filter.call(subject)

		if only_auth and not is_auth:
			continue
		if not is_auth and history.is_auth(tick, subject):
			continue

		var subject_snapshot := history.ensure_snapshot(tick, subject, false) #!!
		assert(not property_pool.get_properties_of(subject).is_empty(), "Subject present in property pool without properties! Please report a bug!")
		for property in property_pool.get_properties_of(subject):
			subject_snapshot.record_property(property)
			snapshot.record_property(subject, property)
		snapshot.set_auth(subject, is_auth)
		subject_snapshot.set_auth(is_auth)

		match history:
			_rb_input_history:
				_logger.trace("Recorded input @%d: %s", [tick, snapshot])
			_rb_state_history:
				_logger.trace("Recorded state @%d: %s", [tick, snapshot])

func _restore_latest(tick: int, history: _PerObjectHistory) -> bool:
	var any_applied := false

	for subject in history.subjects():
		# Grab latest snapshot up to tick
		var snapshot := history.get_latest_snapshot(tick, subject)

		# Apply if any
		if snapshot:
			snapshot.apply()
			any_applied = true

			match history:
				_rb_input_history: _logger.trace("Restored input @%d: %s", [tick, snapshot])
				_rb_state_history: _logger.trace("Restored state @%d: %s", [tick, snapshot])

	return any_applied

func _merge_snapshot(snapshot: _Snapshot, snapshots: _HistoryBuffer, reverse: bool = false) -> bool:
	var tick := snapshot.tick

	if not snapshots.has_at(snapshot.tick):
		snapshots.set_at(tick, snapshot)
		return true

	var original_snapshot := snapshots.get_at(tick) as _Snapshot
	if reverse:
		var original_subjects := original_snapshot.get_auth_subjects()
		var incoming_subjects := snapshot.get_auth_subjects()

		# Merge the original snapshot on top of the incoming
		# This prevents players from changing history, e.g. rewrite their past
		# inputs
		snapshots.set_at(tick, snapshot)
		snapshot.merge(original_snapshot)

		# Only return true if we've received inputs for a new node
		return incoming_subjects.any(func(it): return not original_subjects.has(it))
	else:
		return original_snapshot.merge(snapshot)

func _merge_history(snapshot: _Snapshot, history: _PerObjectHistory, reverse: bool = false) -> bool:
	var tick := snapshot.tick
	var has_updated := false

	if tick < NetworkRollback.history_start:
		_logger.warning("Snapshot being merged is too old! (@%d)", [tick])
		return false

	for subject in snapshot.get_subjects():
		var object_snapshot := history.ensure_snapshot(tick, subject, not reverse)

		# Never overwrite auth data
		if object_snapshot.is_auth() and not snapshot.is_auth(subject):
			continue

		for property in snapshot.get_subject_properties(subject):
			# If merging in reverse, don't update anything that we already have
			# a value for - only accept previously unknown property values
			if reverse and object_snapshot.has_value(property):
				continue

			var original_value := object_snapshot.get_value(property)
			var new_value := snapshot.get_property(subject, property)

			object_snapshot.set_value(property, new_value)
			if not has_updated and original_value != new_value:
				has_updated = true
		object_snapshot.set_auth(snapshot.is_auth(subject))

	return has_updated

func _get_latest_for(subjects: Array, tick: int, history: _PerObjectHistory) -> int:
	var latest := -1

	for subject in subjects:
		var subject_latest := history.get_latest_tick(tick, subject)
		if subject_latest < 0:
			continue

		# Should we track `mini()` instead?
		latest = maxi(latest, subject_latest)

	return latest

func _get_earliest_for(subjects: Array, tick: int, history: _PerObjectHistory) -> int:
	var earliest := -1

	for subject in subjects:
		var subject_latest := history.get_latest_tick(tick, subject)
		if subject_latest < 0:
			return -1

		if earliest < 0:
			earliest = earliest
		else:
			earliest = mini(earliest, subject_latest)

	return earliest
