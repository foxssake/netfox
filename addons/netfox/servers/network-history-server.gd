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

func record_input(tick: int) -> void:
	_record(tick, _rb_input_snapshots, _rb_input_properties, false, func(subject: Node):
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

func record_sync_state(tick: int) -> void:
	_record(tick, _sync_state_snapshots, _sync_state_properties, true, func(subject: Node):
		return subject.is_multiplayer_authority()
	)

func restore_rollback_input(tick: int) -> bool:
	return _restore(tick, _rb_input_snapshots)

func restore_rollback_state(tick: int) -> bool:
	return _restore(tick, _rb_state_snapshots)

func restore_synchronizer_state(tick: int) -> bool:
	return _restore(tick, _sync_state_snapshots)

func get_rollback_input_snapshot(tick: int) -> Snapshot:
	return _rb_input_snapshots.get_at(tick)

func get_rollback_state_snapshot(tick: int) -> Snapshot:
	return _rb_state_snapshots.get_at(tick)

func get_synchronizer_state_snapshot(tick: int) -> Snapshot:
	return _sync_state_snapshots.get_at(tick)

func merge_snapshot(snapshot: Snapshot, snapshots: _HistoryBuffer) -> Snapshot:
	var tick := snapshot.tick
	if not snapshots.has_at(snapshot.tick):
		snapshots.set_at(tick, snapshot)
		return snapshot

	var stored_snapshot := snapshots.get_at(tick) as Snapshot
	stored_snapshot.merge(snapshot)

	return stored_snapshot

func merge_rollback_input(snapshot: Snapshot) -> Snapshot:
	return merge_snapshot(snapshot, _rb_input_snapshots)

func merge_rollback_state(snapshot: Snapshot) -> Snapshot:
	return merge_snapshot(snapshot, _rb_state_snapshots)

func merge_synchronizer_state(snapshot: Snapshot) -> Snapshot:
	return merge_snapshot(snapshot, _sync_state_snapshots)

func get_data_age_for(what: Node, tick: int) -> int:
	if _rb_state_snapshots.is_empty() or _rb_input_snapshots.is_empty():
		return -1

	var earliest_tick := mini(_rb_state_snapshots.keys().min(), _rb_input_snapshots.keys().min())
	for i in range(tick, earliest_tick - 1, -1):
		var input_snapshot := get_rollback_input_snapshot(i)
		var state_snapshot := get_rollback_state_snapshot(i)

		var has_input := input_snapshot != null and input_snapshot.has_subject(what, true)
		var has_state := state_snapshot != null and state_snapshot.has_subject(what, true)

		if has_input or has_state:
			return tick - i
	return -1

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
#		if not is_auth and snapshot.is_auth(subject):
#			continue

		for property in property_pool.get_properties_of(subject):
			snapshot.record_property(subject, property)
			updates.append([subject, property, snapshot.get_property(subject, property), is_auth])
		snapshot.set_auth(subject, is_auth)

	match snapshots:
		_rb_input_snapshots:
			_logger.debug("Updates to%s input @%d: %s" % [" new" if is_new else "", tick, updates])
			_logger.debug("Recorded input @%d: %s", [tick, snapshot])
		_rb_state_snapshots:
			_logger.debug("Updates to%s state @%d: %s" % [" new" if is_new else "", tick, updates])
			_logger.debug("Recorded state @%d: %s", [tick, snapshot])

func _restore(tick: int, snapshots: _HistoryBuffer) -> bool:
	if not snapshots.has_latest_at(tick):
		return false

	var snapshot := snapshots.get_latest_at(tick) as Snapshot
	snapshot.apply()
	
	match snapshots:
		_rb_input_snapshots: _logger.debug("Restored input @%d: %s", [tick, snapshot])
		_rb_state_snapshots: _logger.debug("Restored state @%d: %s", [tick, snapshot])
	
	return true
