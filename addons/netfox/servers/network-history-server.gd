extends Node
class_name _NetworkHistoryServer

# @public class

## Tracks the history of objects' properties
##
## History is stored for [br]
## 1- rollback state and inputs,
## 2- syncronized states,
## 3- input_sender inputs,
## 4- simulator states.
## [br][br]
## Keeping history is needed for rewind operations and it also enables comparing,
## sending diff states.

var _rb_input_properties := _PropertyPool.new()
var _rb_state_properties := _PropertyPool.new()
var _sync_state_properties := _PropertyPool.new()
var _input_sender_properties := _PropertyPool.new()
var _simulator_properties := _PropertyPool.new()

var _rb_history_size := NetworkRollback.history_limit
var _sync_history_size := ProjectSettings.get_setting("netfox/state_synchronizer/history_limit", 64) as int
# InputSender and Simulator histories also hold ticks in the future: clients
# stamp inputs ahead and predict their own state ahead. So their buffers are
# history_limit ticks of the past, plus room for the future, see
# _SimulatorTimeTracker.get_future_history_ticks().
var _input_sender_history_size := ProjectSettings.get_setting("netfox/input_sender/history_limit", 64) as int \
	+ _SimulatorTimeTracker.get_future_history_ticks()
var _simulator_history_size := ProjectSettings.get_setting("netfox/simulator/history_limit", 64) as int \
	+ _SimulatorTimeTracker.get_future_history_ticks()

var _ignored_subjects := _Set.new()

# Source of truth for history
var _rb_input_history := _PerObjectHistory.new(_rb_history_size)
var _rb_state_history := _PerObjectHistory.new(_rb_history_size)
var _sync_history := _PerObjectHistory.new(_sync_history_size)
var _input_sender_history := _PerObjectHistory.new(_input_sender_history_size)
var _simulator_history := _PerObjectHistory.new(_simulator_history_size)

# Cached snapshots for syncing
var _rb_input_snapshots := _HistoryBuffer.new(_rb_history_size)
var _rb_state_snapshots := _HistoryBuffer.new(_rb_history_size)
var _sync_state_snapshots := _HistoryBuffer.new(_sync_history_size)
var _input_sender_snapshots := _HistoryBuffer.new(_input_sender_history_size)
var _simulator_snapshots := _HistoryBuffer.new(_simulator_history_size)

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

## Register a input_sender input property
func register_input_sender(node: Node, property: NodePath) -> void:
	_input_sender_properties.add(node, property)

## Deregister a input_sender input propert
func deregister_input_sender(node: Node, property: NodePath) -> void:
	_input_sender_properties.erase(node, property)

## Register a simulator property
func register_simulator(node: Node, property: NodePath) -> void:
	_simulator_properties.add(node, property)

## Deregister a simulator property
func deregister_simulator(node: Node, property: NodePath) -> void:
	_simulator_properties.erase(node, property)

## Deregister a node, no longer tracking any property it had registered using
## any of the [code]register_*()[/code] methods
func deregister(node: Node) -> void:
	# Deregister properties
	_rb_state_properties.erase_subject(node)
	_rb_input_properties.erase_subject(node)
	_sync_state_properties.erase_subject(node)
	_input_sender_properties.erase_subject(node)
	_simulator_properties.erase_subject(node)

	# Erase from per-object history
	_rb_state_history.erase_subject(node)
	_rb_input_history.erase_subject(node)
	_sync_history.erase_subject(node)
	_input_sender_history.erase_subject(node)
	_simulator_history.erase_subject(node)

	# Erase from per-tick history
	for history in [_rb_state_snapshots, _rb_input_snapshots,\
	_sync_state_snapshots, _input_sender_snapshots, _simulator_snapshots]:

		for value in history.values():
			var snapshot := value as _Snapshot
			snapshot.erase_subject(node)

## Forget all recorded history, while keeping the registered properties
## [br][br]
## History is indexed by tick, so data from a previous session must not carry
## over to the next one. Called by [method _NetworkTime.stop].
func reset() -> void:
	_rb_input_history = _PerObjectHistory.new(_rb_history_size)
	_rb_state_history = _PerObjectHistory.new(_rb_history_size)
	_sync_history = _PerObjectHistory.new(_sync_history_size)

	_rb_input_snapshots = _HistoryBuffer.new(_rb_history_size)
	_rb_state_snapshots = _HistoryBuffer.new(_rb_history_size)
	_sync_state_snapshots = _HistoryBuffer.new(_sync_history_size)

	_ignored_subjects.clear()

## Do not record [param subject]
## [br][br]
## Can be used in [code]_rollback_tick()[/code] in case node prediction is
## enabled, but state can't be reasonably predicted.
## [br][br]
## Subjects stay ignored until [method flush_ignores] is called. This is done
## by default after every rollback tick.
func ignore(subject: Node) -> void:
	_ignored_subjects.add(subject)

## Clear the list of ignored subjects
## [br][br]
## Calling this method undoes all previous [method ignore] calls.
func flush_ignores() -> void:
	_ignored_subjects.clear()

## Return the latest tick where any of the [param subjects] had rollback
## state data available
func get_latest_state_tick_for(subjects: Array, tick: int) -> int:
	return _get_latest_for(subjects, tick, _rb_state_history)

## Return how old is the latest rollback state data for any of the
## [param subjects], in ticks
func get_state_age_for(subjects: Array, tick: int) -> int:
	var latest_state := get_latest_state_tick_for(subjects, tick)
	if latest_state < 0:
		return -1
	else:
		return tick - latest_state

## Return the latest tick where any of the [param subjects] had rollback
## input data available
func get_latest_input_for(subjects: Array, tick: int) -> int:
	return _get_latest_for(subjects, tick, _rb_input_history)

## Get the latest tick where any of the [param subjects] had input_sender data
## available
func get_latest_input_sender_for(subjects: Array, tick: int) -> int:
	return _get_latest_for(subjects, tick, _input_sender_history)

## Get the latest tick where any of the [param subjects] had simulator data
## available
func get_latest_simulator_for(subjects: Array, tick: int) -> int:
	return _get_latest_for(subjects, tick, _simulator_history)

## Get the latest tick at or before [param tick] where every one of the
## [param subjects] has auth (received) simulator state. Returns -1 if there's
## none.
## [br][br]
## Auth is checked on the per-object history, not on the per-tick snapshot. A
## diff state only carries the subjects whose properties changed, so a subject
## that didn't change is missing from that tick's snapshot even though the host
## sent it. Its auth state is carried forward in the per-object history instead,
## see [method _merge_simulator].
func get_latest_simulator_for_snapshot(subjects: Array, tick: int) -> int:
	# Walk backwards from the newest tick, so the first match is the latest one
	var latest_index := mini(tick, _simulator_snapshots.get_latest_index())

	for index in range(latest_index, _simulator_snapshots.get_earliest_index() - 1, -1):
		if not _simulator_snapshots.has_at(index):
			continue

		var has_all_auth := true
		for subject in subjects:
			if not _simulator_history.is_auth(index, subject):
				has_all_auth = false
				break

		if has_all_auth:
			return index

	return -1

## Return how old is the latest rollback input data for any of the
## [param subjects], in ticks
func get_input_age_for(subjects: Array, tick: int) -> int:
	var latest_input := get_latest_input_for(subjects, tick)
	if latest_input < 0:
		return -1
	else:
		return tick - latest_input

## Record currently registered rollback state properties for [param subject] at
## [param tick].
func push_rollback_state(subject: Node, tick: int) -> void:
	var subject_snapshot := _rb_state_history.ensure_snapshot(tick, subject, false)
	if subject_snapshot == null:
		_logger.warning("Dropping seeded state @%d for subject %s as out-of-bounds", [tick, subject])
		return

	var snapshot := _rb_state_snapshots.get_at(tick, _Snapshot.new(tick)) as _Snapshot
	if not _rb_state_snapshots.has_at(tick):
		_rb_state_snapshots.set_at(tick, snapshot)

	var is_auth := subject.is_multiplayer_authority()
	for property in _rb_state_properties.get_properties_of(subject):
		subject_snapshot.record_property(property)
		snapshot.record_property(subject, property)

	snapshot.set_auth(subject, is_auth)
	subject_snapshot.set_auth(is_auth)

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

func _record_input_sender(tick: int) -> void:
	_record(tick, _input_sender_history, _input_sender_snapshots, _input_sender_properties,\
	true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

func _record_simulator(tick: int) -> void:
	_record(tick, _simulator_history, _simulator_snapshots, _simulator_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

# Records the current state of the given simulator subjects for the given tick,
# even if we don't have authority over them.
#
# Used by SimulatorServer to record simulators one by one, e.g. predicted state
# of local authoritative simulators (we own the input, but not the state).
# Properties are the ones registered with [method register_simulator].
#
# Existing auth data is never overwritten. Only the per-object history is
# written, no per-tick snapshot.
func _record_simulator_subjects(subjects: Array, tick: int) -> void:
	for subject in subjects:
		assert(subject is Node, "Only nodes supported for now!")

		# Never overwrite auth data, e.g. truth received from the host
		if _simulator_history.is_auth(tick, subject):
			continue

		var properties := _simulator_properties.get_properties_of(subject)
		assert(not properties.is_empty(), "Simulator subject recorded without registered properties! Please report a bug!")

		var object_snapshot := _simulator_history.ensure_snapshot(tick, subject, true)
		if object_snapshot == null:
			_logger.warning("Dropping recorded tick @%d for subject %s as out-of-bounds", [tick, subject])
			continue

		for property in properties:
			object_snapshot.record_property(property)
		object_snapshot.set_auth((subject as Node).is_multiplayer_authority())

		_logger.trace("Recorded simulator state @%d: %s", [tick, object_snapshot])

func _restore_rollback_input(tick: int) -> bool:
	return _restore_latest(tick, _rb_input_history)

func _restore_rollback_state(tick: int) -> bool:
	return _restore_latest(tick, _rb_state_history)

func _restore_synchronizer_state(tick: int) -> bool:
	return _restore_latest(tick, _sync_history)

# Applies the latest input_sender inputs at or before the given tick, but only
# to the given subjects, so a single InputSender can be restored without
# touching the others. Nothing is written to the history.
func _restore_input_sender_subjects(subjects: Array, tick: int) -> void:
	for subject in subjects:
		var object_snapshot := _input_sender_history.get_latest_snapshot(tick, subject)
		if object_snapshot:
			object_snapshot.apply()

# Applies the auth simulator state at the given tick to each of the subjects.
# Values come from the per-object history, so diffs received for the tick are
# already merged on top of the previous auth state.
#
# NOTE: On a fresh connection, if a diff arrives before the first full state,
# the auth state only holds the properties in that diff. Only those are
# applied, the rest are filled in by the next full state.
func _restore_simulator_subjects(subjects: Array, tick: int) -> void:
	for subject in subjects:
		# Shouldn't happen, the tick is picked from received snapshots. It only
		# can if the state was stored in _simulator_snapshots, but was too old
		# for _merge_history. Never apply non-auth (e.g. predicted) data as truth.
		if not _simulator_history.is_auth(tick, subject):
			_logger.warning("No auth simulator state for %s @%d, skipping restore", [subject, tick])
			continue

		var object_snapshot := _simulator_history.get_latest_snapshot(tick, subject)
		object_snapshot.apply()

# Restores non authoritative simulators to known last state.
func _restore_simulator(tick: int) -> bool:
	return _restore_latest(tick, _simulator_history, func(subject: Node) -> bool:
		return not subject.is_multiplayer_authority()
)

func _get_rollback_input_snapshot(tick: int) -> _Snapshot:
	return _rb_input_snapshots.get_at(tick)

func _get_rollback_state_snapshot(tick: int) -> _Snapshot:
	return _rb_state_snapshots.get_at(tick)

func _get_synchronizer_state_snapshot(tick: int) -> _Snapshot:
	return _sync_state_snapshots.get_at(tick)

func _get_input_sender_snapshot(tick: int) -> _Snapshot:
	return _input_sender_snapshots.get_at(tick)

func _get_simulator_snapshot(tick: int) -> _Snapshot:
	return _simulator_snapshots.get_at(tick)

func _merge_rollback_input(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _rb_input_snapshots, true)
	return _merge_history(snapshot, _rb_input_history, true)

func _merge_rollback_state(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _rb_state_snapshots)
	return _merge_history(snapshot, _rb_state_history)

func _merge_synchronizer_state(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _sync_state_snapshots, true)
	return _merge_history(snapshot, _sync_history)

func _merge_input_sender(snapshot: _Snapshot) -> bool:
	_merge_snapshot(snapshot, _input_sender_snapshots, true)
	return _merge_history(snapshot, _input_sender_history, true)

# Merges a simulator state received from the host, either full or diff.
#
# Works the same way as merging rollback state: the per-tick snapshot keeps what
# was received, and the per-object history is merged with carry-forward. A diff
# only contains properties that changed since the previous tick, carry-forward
# fills in the rest from the previous tick.
#
# Auth data in the history must only ever hold values received from the host.
# Local authoritative simulators record their own predictions into the same
# history (see _record_simulator_subjects), so before merging, each subject's
# entry at this tick is reset to its latest auth state. This way carry-forward
# never copies predicted values into auth data.
func _merge_simulator(snapshot: _Snapshot) -> bool:
	# Auth subjects include the ones a diff sent without any changed property.
	# Resetting them carries their latest auth state forward to this tick, so
	# the tick counts as truth for them too, see get_latest_simulator_for_snapshot.
	for subject in snapshot.get_auth_subjects():
		_simulator_history.reset_to_auth(snapshot.tick, subject)

	_merge_snapshot(snapshot, _simulator_snapshots)
	return _merge_history(snapshot, _simulator_history)

func _record(tick: int, history: _PerObjectHistory, snapshots: _HistoryBuffer, property_pool: _PropertyPool, only_auth: bool, auth_filter: Callable) -> void:
	var snapshot := snapshots.get_at(tick, _Snapshot.new(tick)) as _Snapshot
	if not snapshots.has_at(tick):
		snapshots.set_at(tick, snapshot)

	for subject in property_pool.get_subjects_raw():
		assert(subject is Node, "Only nodes supported for now!")

		# Don't record history when subject is not alive to prevent state corruption.
		if history == _rb_state_history and not RollbackLivenessServer.is_alive(subject, tick - 1):
			continue

		if _ignored_subjects.has(subject):
			continue

		var is_auth := auth_filter.call(subject)

		if only_auth and not is_auth:
			continue
		if not is_auth and history.is_auth(tick, subject):
			continue

		var subject_snapshot := history.ensure_snapshot(tick, subject, false)
		if subject_snapshot == null:
			# Usually this happens when the tick is close to NetworkRollback.history_start, and the
			# time sync is off by just enough to push it over the edge
			# e.g. tick arrives slightly in the future, resim goes from the start of history, ring
			# buffer suddenly has no room because its head is in the future
			_logger.warning("Dropping recorded tick @%d for subject %s as out-of-bounds", [tick, subject])
			continue

		var properties := property_pool.get_properties_of_raw(subject)
		assert(not properties.is_empty(), "Subject present in property pool without properties! Please report a bug!")
		for property in properties:
			var value: Variant = subject.get_indexed(property)
			subject_snapshot.set_value(property, value)
			snapshot.set_property(subject, property, value)
		snapshot.set_auth(subject, is_auth)
		subject_snapshot.set_auth(is_auth)

		match history:
			_rb_input_history:
				_logger.trace("Recorded input @%d: %s", [tick, snapshot])
			_rb_state_history:
				_logger.trace("Recorded state @%d: %s", [tick, snapshot])

# Restore latest for given history. Optional filter can be used to filter subjects.
# Return false from filter function to not restore.
# Return true from filter function to restore.
# func(subject: Node) -> bool:
#		return not subject.is_multiplayer_authority()
func _restore_latest(tick: int, history: _PerObjectHistory, filter: Callable = Callable()) -> bool:
	var any_applied := false

	for subject in history.subjects_raw():
		# Optional filter. example: to only restore subjects we dont have authority over.
		if filter.is_valid() and not filter.call(subject):
			continue

		# Grab latest snapshot up to tick
		var snapshot := history.get_latest_snapshot(tick, subject)

		# Apply if any
		if snapshot:
			snapshot.apply()
			any_applied = true

			match history:
				_simulator_history: _logger.trace("Restored simulation state @%d: %s", [tick, snapshot])
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
		match history:
			_rb_input_history: _logger.warning("Input being merged is too old! (@%d)", [tick])
			_rb_state_history: _logger.warning("State being merged is too old! (@%d)", [tick])
			_sync_history: _logger.warning("Sync state being merged is too old! (@%d)", [tick])
			_: _logger.warning("Snapshot being merged is too old! (@%d)", [tick])
		return false

	for subject in snapshot.get_subjects():
		var object_snapshot := history.ensure_snapshot(tick, subject, not reverse)
		if object_snapshot == null:
			_logger.warning("Snapshot being merged is out of bounds! (@%d)", [tick])
			continue

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
