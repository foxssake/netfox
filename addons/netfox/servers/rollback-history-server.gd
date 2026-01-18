extends Node
class_name _RollbackHistoryServer
# TODO: Rename to Network(ed?)HistoryServer

var _input_properties: Array = []
var _state_properties: Array = []
var _sync_state_properties: Array = [] # [node, property] tuples

var _rollback_input_snapshots: Dictionary = {} # tick to Snapshot
var _rollback_state_snapshots: Dictionary = {} # tick to Snapshot
var _sync_state_snapshots: Dictionary = {} # tick to Snapshot

static var _logger := NetfoxLogger._for_netfox("RollbackHistoryServer")

func register_property(node: Node, property: NodePath, pool: Array) -> void:
	var entry := RecordedProperty.key_of(node, property)

	# TODO: Accelerate this check, maybe with _Set
	if not pool.has(entry):
		pool.append(entry)

func deregister_property(node: Node, property: NodePath, pool: Array) -> void:
	pool.erase([node, property])

func register_state(node: Node, property: NodePath) -> void:
	register_property(node, property, _state_properties)

func deregister_state(node: Node, property: NodePath) -> void:
	deregister_property(node, property, _state_properties)

func register_input(node: Node, property: NodePath) -> void:
	register_property(node, property, _input_properties)

func deregister_input(node: Node, property: NodePath) -> void:
	deregister_property(node, property, _input_properties)

func register_sync_state(node: Node, property: NodePath) -> void:
	register_property(node, property, _sync_state_properties)

func deregister_sync_state(node: Node, property: NodePath) -> void:
	deregister_property(node, property, _sync_state_properties)

# TODO: Private
# TODO: Replace `predicted_nodes` with a filter callable
func record_tick(tick: int, snapshots: Dictionary, properties: Array, predicted_nodes: Array[Node]) -> void:
	# Ensure snapshot
	var snapshot := snapshots.get(tick) as Snapshot
	if snapshot == null:
		snapshot = Snapshot.new(tick)
		snapshots[tick] = snapshot

	# Record values
	var updated := []
	for entry in properties:
		var node := entry[0] as Node
		var property := entry[1] as NodePath
		var is_auth := node.is_multiplayer_authority() and not predicted_nodes.has(node)
		
		# HACK: Figure out proper API
		# Passing in `RollbackSimulationServer.get_predicted_nodes()` accounts
		# for *simulated* nodes, but not for nodes with *just* state
		if properties == _state_properties:
			var input_snapshot := _rollback_input_snapshots.get(tick) as Snapshot
			if RollbackSimulationServer.is_predicting(input_snapshot, node):
				is_auth = false
		
		if snapshot.merge_property(node, property, RecordedProperty.extract(entry), is_auth):
			updated.append([node, property, RecordedProperty.extract(entry), is_auth])

	_logger.trace("Recorded %d props for tick @%d: %s", [properties.size(), tick, snapshot])

func record_input(tick: int) -> void:
	record_tick(tick, _rollback_input_snapshots, _input_properties, [])

func record_state(tick: int) -> void:
	record_tick(tick, _rollback_state_snapshots, _state_properties, RollbackSimulationServer.get_predicted_nodes())

func record_sync_state(tick: int) -> void:
	# TODO: Reduce duplication
	# Record values
	var snapshot := Snapshot.new(tick)
	for entry in _sync_state_properties:
		var node := entry[0] as Node
		var property := entry[1] as NodePath
		var is_auth := node.is_multiplayer_authority()
		if not is_auth:
			continue

		snapshot.merge_property(node, property, RecordedProperty.extract(entry), is_auth)

	if snapshot.is_empty():
		# No auth data in snapshot, nothing to do
		return

	if not _sync_state_snapshots.has(tick):
		_sync_state_snapshots[tick] = snapshot
	else:
		(_sync_state_snapshots[tick] as Snapshot).merge(snapshot)

# TODO: Private
func restore_tick(tick: int, snapshots: Dictionary) -> bool:
	# TODO: Prettier recreation of HistoryBuffer logic and / or reuse HistoryBuffer
	if snapshots.is_empty() or tick < snapshots.keys().min():
		return false
	while not snapshots.has(tick) and tick >= snapshots.keys().min():
		tick -= 1

	var snapshot := snapshots[tick] as Snapshot
	if snapshots == _sync_state_snapshots:
		_logger.debug("Restoring snapshot: %s", [snapshot])
	snapshot.apply()
	return true

func restore_rollback_input(tick: int) -> bool:
	return restore_tick(tick, _rollback_input_snapshots)

func restore_rollback_state(tick: int) -> bool:
	return restore_tick(tick, _rollback_state_snapshots)

func restore_synchronizer_state(tick: int) -> bool:
	return restore_tick(tick, _sync_state_snapshots)

func trim_history(earliest_tick: int) -> void:
	var snapshot_pools := [_rollback_input_snapshots, _rollback_state_snapshots, _sync_state_snapshots] as Array[Dictionary]

	for snapshots in snapshot_pools:
		while not snapshots.is_empty():
			var earliest_stored_tick := snapshots.keys().min()
			if earliest_stored_tick >= earliest_tick:
				break
			snapshots.erase(earliest_stored_tick)

# TODO: Keep snapshots private
# TODO: Private
func get_snapshot(tick: int, snapshots: Dictionary) -> Snapshot:
	return snapshots.get(tick) as Snapshot

func get_rollback_input_snapshot(tick: int) -> Snapshot:
	return get_snapshot(tick, _rollback_input_snapshots)

func get_rollback_state_snapshot(tick: int) -> Snapshot:
	return get_snapshot(tick, _rollback_state_snapshots)

func get_synchronizer_state_snapshot(tick: int) -> Snapshot:
	return get_snapshot(tick, _sync_state_snapshots)

# TODO: Keep snapshots private
func merge_snapshot(snapshot: Snapshot, snapshots: Dictionary) -> Snapshot:
	var tick := snapshot.tick
	if not snapshots.has(snapshot.tick):
		snapshots[tick] = snapshot
		return snapshot

	var stored_snapshot := snapshots[tick] as Snapshot
	stored_snapshot.merge(snapshot)

	return stored_snapshot

func merge_rollback_input(snapshot: Snapshot) -> Snapshot:
	return merge_snapshot(snapshot, _rollback_input_snapshots)

func merge_rollback_state(snapshot: Snapshot) -> Snapshot:
	return merge_snapshot(snapshot, _rollback_state_snapshots)

func merge_synchronizer_state(snapshot: Snapshot) -> Snapshot:
	return merge_snapshot(snapshot, _sync_state_snapshots)

func get_data_age_for(what: Node, tick: int) -> int:
	if _rollback_state_snapshots.is_empty() or _rollback_input_snapshots.is_empty():
		return -1

	var earliest_tick := mini(_rollback_state_snapshots.keys().min(), _rollback_input_snapshots.keys().min())
	for i in range(tick, earliest_tick - 1, -1):
		var input_snapshot := get_rollback_input_snapshot(i)
		var state_snapshot := get_rollback_state_snapshot(i)

		var has_input := input_snapshot != null and input_snapshot.has_node(what, true)
		var has_state := state_snapshot != null and state_snapshot.has_node(what, true)

		if has_input or has_state:
			return tick - i
	return -1
