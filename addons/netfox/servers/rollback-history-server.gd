extends Node
class_name _RollbackHistoryServer

var _recorded_properties: Array[RecordedProperty] = []
var _snapshots: Dictionary = {} # tick to Snapshot

func register_property(node: Node, property: NodePath) -> void:
	var entry := RecordedProperty.new(node, property)

	# TODO: Accelerate this check, maybe with _Set
	if not _recorded_properties.has(entry):
		_recorded_properties.append(entry)

func deregister_property(node: Node, property: NodePath) -> void:
	# TODO: Accelerate, maybe with _Set
	_recorded_properties.erase(RecordedProperty.new(node, property))

func record_tick(tick: int) -> void:
	# Ensure snapshot
	var snapshot := _snapshots.get(tick) as Snapshot
	if snapshot == null:
		snapshot = Snapshot.new(tick)

	# Record values
	for entry in _recorded_properties:
		var recorded_property := entry as RecordedProperty
		snapshot.data[recorded_property] = recorded_property.extract_value()

func restore_tick(tick: int) -> bool:
	if not _snapshots.has(tick):
		return false

	var snapshot := _snapshots[tick] as Snapshot
	for entry in snapshot.data.keys():
		var recorded_property := entry as RecordedProperty
		var value = snapshot.data[entry]
		recorded_property.apply_value(value)
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
	stored_snapshot.data.merge(snapshot.data)

	return stored_snapshot
