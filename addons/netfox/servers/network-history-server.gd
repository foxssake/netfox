extends Node
class_name _NetworkHistoryServer

var _rb_input_properties := _PropertyPool.new()
var _rb_state_properties := _PropertyPool.new()
var _sync_state_properties := _PropertyPool.new()

var _rb_history_size := NetworkRollback.history_limit
var _sync_history_size := ProjectSettings.get_setting("netfox/state_synchronizer/history_limit", 64) as int

var _rb_input_snapshots := _HistoryBuffer.new(_rb_history_size)
var _rb_state_snapshots := _HistoryBuffer.new(_rb_history_size)
var _sync_state_snapshots := _HistoryBuffer.new(_sync_history_size)

var _rb_input_history := _PerObjectHistory.new(_rb_history_size)
var _rb_state_history := _PerObjectHistory.new(_rb_history_size)
var _sync_history := _PerObjectHistory.new(_sync_history_size)

static var _logger := NetfoxLogger._for_netfox("NetworkHistoryServer")

func register_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.add(node, property)

func deregister_state(node: Node, property: NodePath) -> void:
	_rb_state_properties.erase(node, property)

func register_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.add(node, property)

func deregister_input(node: Node, property: NodePath) -> void:
	_rb_input_properties.erase(node, property)

func register_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.add(node, property)

func deregister_sync_state(node: Node, property: NodePath) -> void:
	_sync_state_properties.erase(node, property)

func deregister(node: Node) -> void:
	_rb_state_properties.erase_subject(node)
	_rb_input_properties.erase_subject(node)
	_sync_state_properties.erase_subject(node)

	_rb_state_history.erase_subject(node)
	_rb_input_history.erase_subject(node)
	_sync_history.erase_subject(node)

func record_input(tick: int) -> void:
	_record(tick, _rb_input_snapshots, _rb_input_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)
	_record_history(tick, _rb_input_history, _rb_input_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

func record_state(tick: int) -> void:
	var input_snapshot := get_rollback_input_snapshot(tick - 1)
	_record(tick, _rb_state_snapshots, _rb_state_properties, false, func(subject: Node):
		if not subject.is_multiplayer_authority():
			return false
		if RollbackSimulationServer.is_predicting(input_snapshot, subject):
			return false
		return true
	)
	_record_history(tick, _rb_state_history, _rb_state_properties, false, func(subject: Node):
		if not subject.is_multiplayer_authority():
			return false
		if RollbackSimulationServer.is_predicting(input_snapshot, subject):
			return false
		return true
	)

func record_sync_state(tick: int) -> void:
	_record(tick, _sync_state_snapshots, _sync_state_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)
	_record_history(tick, _sync_history, _sync_state_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

func restore_rollback_input(tick: int) -> bool:
	_restore_latest(tick, _rb_input_history)
	return true
	return _restore(tick, _rb_input_snapshots)

func restore_rollback_state(tick: int) -> bool:
	_restore_latest(tick, _rb_state_history)
	return true
	return _restore(tick, _rb_state_snapshots)

func restore_synchronizer_state(tick: int) -> bool:
	_restore_latest(tick, _sync_history)
	return true
	return _restore(tick, _sync_state_snapshots)

func get_rollback_input_snapshot(tick: int) -> Snapshot:
	return _rb_input_snapshots.get_at(tick)

func get_rollback_state_snapshot(tick: int) -> Snapshot:
	return _rb_state_snapshots.get_at(tick)

func get_synchronizer_state_snapshot(tick: int) -> Snapshot:
	return _sync_state_snapshots.get_at(tick)

func merge_rollback_input(snapshot: Snapshot) -> bool:
	_merge_uh_please(snapshot, _rb_input_history, true)
	return _merge(snapshot, _rb_input_snapshots, true)

func merge_rollback_state(snapshot: Snapshot) -> bool:
	_merge_uh_please(snapshot, _rb_state_history)
	return _merge(snapshot, _rb_state_snapshots)

func merge_synchronizer_state(snapshot: Snapshot) -> bool:
	_merge_uh_please(snapshot, _sync_history)
	return _merge(snapshot, _sync_state_snapshots)

func get_input_age_for(subjects: Array, tick: int) -> int:
	return _get_age_for(subjects, tick, _rb_input_snapshots)

func get_state_age_for(subjects: Array, tick: int) -> int:
	return _get_age_for(subjects, tick, _rb_state_snapshots)

func _record_history(tick: int, history: _PerObjectHistory, property_pool: _PropertyPool, only_auth: bool, auth_filter: Callable) -> void:
	for subject in property_pool.get_subjects():
		assert(subject is Node, "Only nodes supported for now!")

		var is_auth := auth_filter.call(subject)

		if only_auth and not is_auth:
			continue
		if not is_auth and history.is_auth(tick, subject):
			continue
		
		var snapshot := history.ensure_snapshot(tick, subject, false) #!!
		assert(not property_pool.get_properties_of(subject).is_empty(), "Subject present in property pool without properties! Please report a bug!")
		for property in property_pool.get_properties_of(subject):
			snapshot.record_property(property)
		snapshot.set_auth(is_auth)

		match history:
			_rb_input_history:
				_logger.debug("Recorded input @%d: %s", [tick, snapshot])
			_rb_state_history:
				_logger.debug("Recorded state @%d: %s", [tick, snapshot])

func _record(tick: int, snapshots: _HistoryBuffer, property_pool: _PropertyPool, only_auth: bool, auth_filter: Callable) -> void:
	# Ensure snapshot
	var snapshot := snapshots.get_at(tick) as Snapshot
	var is_new := false
	if not snapshot:
		snapshot = Snapshot.new(tick)
		snapshots.set_at(tick, snapshot)
		is_new = true

	# Record values
	var updates := []
	for subject in property_pool.get_subjects():
		assert(subject is Node, "Only nodes supported for now!")

		var is_auth := auth_filter.call(subject)

		if only_auth and not is_auth:
			continue
		if not is_auth and snapshot.is_auth(subject):
			continue

		for property in property_pool.get_properties_of(subject):
			snapshot.record_property(subject, property)
			updates.append([subject, property, snapshot.get_property(subject, property), is_auth])
		snapshot.set_auth(subject, is_auth)

#	match snapshots:
#		_rb_input_snapshots:
#			_logger.debug("Updates to%s input @%d: %s" % [" new" if is_new else "", tick, updates])
#			_logger.debug("Recorded input @%d: %s", [tick, snapshot])
#		_rb_state_snapshots:
#			_logger.debug("Updates to%s state @%d: %s" % [" new" if is_new else "", tick, updates])
#			_logger.debug("Recorded state @%d: %s", [tick, snapshot])

func _restore_latest(tick: int, history: _PerObjectHistory) -> void:
	for subject in history.subjects():
		# Grab latest snapshot up to tick
		var snapshot := history.get_latest_snapshot(tick, subject)

		# Apply if any
		if snapshot:
			snapshot.apply()

			match history:
				_rb_input_history: _logger.debug("Restored input @%d: %s", [tick, snapshot])
				_rb_state_history: _logger.debug("Restored state @%d: %s", [tick, snapshot])


func _restore(tick: int, snapshots: _HistoryBuffer) -> bool:
	if not snapshots.has_latest_at(tick):
		return false

	var snapshot := snapshots.get_latest_at(tick) as Snapshot
	snapshot.apply()
	
#	match snapshots:
#		_rb_input_snapshots: _logger.debug("Restored input @%d: %s", [tick, snapshot])
#		_rb_state_snapshots: _logger.debug("Restored state @%d: %s", [tick, snapshot])
	
	return true

func _merge_uh_please(snapshot: Snapshot, history: _PerObjectHistory, reverse: bool = false) -> bool:
	var tick := snapshot.tick
	var has_updated := false

	if tick < NetworkRollback.history_start: # TODO: Local variable?
		# TODO: Warn?
		return false

	for subject in snapshot.get_subjects():
		var object_snapshot := history.ensure_snapshot(tick, subject, not reverse) # TODO: Check if carry-forward is valid here

		# Never overwrite auth data
		if object_snapshot.is_auth() and not snapshot.is_auth(subject):
			continue

		for property in snapshot.get_subject_properties(subject):
			# If merging in reverse, don't update anything that we already have
			# a value for - only accept previously unknown property values
			if reverse and object_snapshot.has_value(property):
				_logger.debug(
					"Rejecting incoming %s:%s=%s for reverse merge, already have %s locally: %s",
					[subject, property, snapshot.get_property(subject, property), object_snapshot.get_value(property), object_snapshot]
				)
				continue

			var original_value := object_snapshot.get_value(property)
			var new_value := snapshot.get_property(subject, property)

			object_snapshot.set_value(property, new_value)
			if not has_updated and original_value != new_value:
				has_updated = true
		object_snapshot.set_auth(snapshot.is_auth(subject))
		match history:
			_rb_input_history: _logger.debug("Merged input @%d: %s", [tick, object_snapshot])

	return has_updated

func _merge(snapshot: Snapshot, snapshots: _HistoryBuffer, reverse: bool = false) -> bool:
	var tick := snapshot.tick

	if not snapshots.has_at(snapshot.tick):
		snapshots.set_at(tick, snapshot)
		return true

	var original_snapshot := snapshots.get_at(tick) as Snapshot
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

func _get_age_for(subjects: Array, tick: int, snapshots: _HistoryBuffer) -> int:
	var at := tick

	# Bounded while loop
	for i in range(1024):
		if not snapshots.has_latest_at(at):
			return -1

		at = snapshots.get_latest_index_at(at)
		var snapshot := snapshots.get_at(at) as Snapshot
		if snapshot.has_subjects(subjects, true):
			return tick - at

	return -1
