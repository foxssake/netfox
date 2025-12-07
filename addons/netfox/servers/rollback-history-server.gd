extends Node
class_name _RollbackHistoryServer

var _input_properties: Array = []
var _state_properties: Array = []

var _snapshots: Dictionary = {} # tick to Snapshot

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

func record_tick(tick: int, properties: Array) -> void:
	# Ensure snapshot
	var snapshot := _snapshots.get(tick) as Snapshot
	if snapshot == null:
		snapshot = Snapshot.new(tick)
		_snapshots[tick] = snapshot

	# Record values
	var updated := []
	for entry in properties:
		var node := entry[0] as Node
		var property := entry[1] as NodePath
		
		if snapshot.merge_property(node, property, RecordedProperty.extract(entry), node.is_multiplayer_authority()):
			updated.append([node, property, RecordedProperty.extract(entry), node.is_multiplayer_authority()])

	_logger.debug("Recorded %d properties: %s; %s", [properties.size(), updated, snapshot])

func record_input(tick: int) -> void:
	record_tick(tick, _input_properties)

func record_state(tick: int) -> void:
	record_tick(tick, _state_properties)

func restore_tick(tick: int) -> bool:
	if not _snapshots.has(tick):
		return false

	var snapshot := _snapshots[tick] as Snapshot
	_logger.debug("Restoring snapshot: %s", [snapshot])
	snapshot.apply()
	return true

func trim_history(earliest_tick: int) -> void:
	while not _snapshots.is_empty():
		var earliest_stored_tick := _snapshots.keys().min()
		if earliest_stored_tick >= earliest_tick:
			break
		_snapshots.erase(earliest_stored_tick)

# TODO: Keep snapshots private
func get_snapshot(tick: int) -> Snapshot:
	return _snapshots.get(tick)

# TODO: Keep snapshots private
func merge_snapshot(snapshot: Snapshot) -> Snapshot:
	var tick := snapshot.tick
	if not _snapshots.has(snapshot.tick):
		_snapshots[tick] = snapshot
		return snapshot

	var stored_snapshot := _snapshots[tick] as Snapshot
	stored_snapshot.merge(snapshot)
#	_snapshots[tick] = stored_snapshot

	return stored_snapshot
