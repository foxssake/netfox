extends Node
class_name _RollbackHistoryServer
# TODO: Rename to Network(ed?)HistoryServer

var _rb_input_properties := _PropertyPool.new()
var _rb_state_properties := _PropertyPool.new()
var _sync_state_properties := _PropertyPool.new()

var _rb_input_snapshots: Dictionary = {} # tick to Snapshot
var _rb_state_snapshots: Dictionary = {} # tick to Snapshot
var _sync_state_snapshots: Dictionary = {} # tick to Snapshot

static var _logger := NetfoxLogger._for_netfox("RollbackHistoryServer")

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

func trim_history(earliest_tick: int) -> void:
	var snapshot_pools := [_rb_input_snapshots, _rb_state_snapshots, _sync_state_snapshots] as Array[Dictionary]

	for snapshots in snapshot_pools:
		while not snapshots.is_empty():
			var earliest_stored_tick := snapshots.keys().min()
			if earliest_stored_tick >= earliest_tick:
				break
			snapshots.erase(earliest_stored_tick)

func get_rollback_input_snapshot(tick: int) -> Snapshot:
	return _rb_input_snapshots.get(tick)

func get_rollback_state_snapshot(tick: int) -> Snapshot:
	return _rb_state_snapshots.get(tick)

func get_synchronizer_state_snapshot(tick: int) -> Snapshot:
	return _sync_state_snapshots.get(tick)

func merge_snapshot(snapshot: Snapshot, snapshots: Dictionary) -> Snapshot:
	var tick := snapshot.tick
	if not snapshots.has(snapshot.tick):
		snapshots[tick] = snapshot
		return snapshot

	var stored_snapshot := snapshots[tick] as Snapshot
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

		var has_input := input_snapshot != null and input_snapshot.has_node(what, true)
		var has_state := state_snapshot != null and state_snapshot.has_node(what, true)

		if has_input or has_state:
			return tick - i
	return -1

func _record(tick: int, snapshots: Dictionary, property_pool: _PropertyPool, only_auth: bool, auth_filter: Callable) -> void:
	# Ensure snapshot
	var snapshot := snapshots.get(tick) as Snapshot
	var is_new := false
	if snapshot == null:
		snapshot = Snapshot.new(tick)
		snapshots[tick] = snapshot
		is_new = true

	# Record values
	var updates := []
	for subject in property_pool.get_subjects():
		assert(subject is Node, "Only nodes supported for now!")

		var is_auth := auth_filter.call(subject)
		if only_auth and not is_auth:
			continue

		for property in property_pool.get_properties_of(subject):
			var value := subject.get_indexed(property)
			if snapshot.merge_property(subject, property, value, is_auth):
				updates.append([subject, property, value, is_auth])

	match snapshots:
		_rb_input_snapshots:
			_logger.debug("Updates to%s input @%d: %s" % [" new" if is_new else "", tick, updates])
			_logger.debug("Recorded input @%d: %s", [tick, snapshot])
		_rb_state_snapshots:
			_logger.debug("Updates to%s state @%d: %s" % [" new" if is_new else "", tick, updates])
			_logger.debug("Recorded state @%d: %s", [tick, snapshot])

func _restore(tick: int, snapshots: Dictionary) -> bool:
	# TODO: Prettier recreation of HistoryBuffer logic and / or reuse HistoryBuffer
	if snapshots.is_empty() or tick < snapshots.keys().min():
		return false
	while not snapshots.has(tick) and tick >= snapshots.keys().min():
		tick -= 1

	var snapshot := snapshots[tick] as Snapshot
	snapshot.apply()
	
	match snapshots:
		_rb_input_snapshots: _logger.debug("Restored input @%d: %s", [tick, snapshot])
		_rb_state_snapshots: _logger.debug("Restored state @%d: %s", [tick, snapshot])
	
	return true
