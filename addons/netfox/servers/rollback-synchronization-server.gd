extends Node
class_name _RollbackSynchronizationServer

var _input_properties: Array = []
var _state_properties: Array = []

static var _logger := NetfoxLogger._for_netfox("RollbackSynchronizationServer")

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

func synchronize_input(tick: int) -> void:
	# Grab snapshot from RollbackHistoryServer
	var snapshot := RollbackHistoryServer.get_snapshot(tick)
	if not snapshot:
		return

	# Filter to input properties
	var input_snapshot := Snapshot.new(tick)
	for property in _input_properties:
		if not snapshot.data.has(property):
			continue
		input_snapshot.data[property] = snapshot.data[property]

	# Transmit
#	_logger.debug("Submitting input: %s", [input_snapshot])
	_submit_input.rpc(_serialize_snapshot(input_snapshot))

func synchronize_state(tick: int) -> void:
	# Grab snapshot from RollbackHistoryServer
	var snapshot := RollbackHistoryServer.get_snapshot(tick)
	if not snapshot:
		return

	# Filter to state properties
	var state_snapshot := Snapshot.new(tick)
	for property in _state_properties:
		if not snapshot.data.has(property):
			continue
		state_snapshot.data[property] = snapshot.data[property]

	# Transmit
#	_logger.debug("Submitting state: %s", [state_snapshot])
	_submit_state.rpc(_serialize_snapshot(state_snapshot))

func _serialize_snapshot(snapshot: Snapshot) -> Variant:
	var serialized_properties := []

	for entry in snapshot.data.keys():
		var node := entry[0] as Node
		var property := entry[1] as NodePath
		var value = snapshot.data[entry]

		serialized_properties.append([str(node.get_path()), str(property), value])

	serialized_properties.append(snapshot.tick)
	return serialized_properties

func _deserialize_snapshot(data: Variant) -> Snapshot:
	var values := data as Array
	var tick := values.pop_back() as int
	
	var snapshot := Snapshot.new(tick)
	for entry in values:
		var entry_data := entry as Array

		var node_path := entry_data[0] as String
		var property := entry_data[1] as String
		var value = entry_data[2]

		var node := get_tree().root.get_node(node_path)
		if not node:
			_logger.warning("Can't find node at path %s, ignoring", [node_path])
			continue

		snapshot.data[RecordedProperty.key_of(node, property)] = value
	
	return snapshot

@rpc("any_peer", "call_remote", "reliable")
func _submit_input(snapshot_data: Variant):
	var snapshot := _deserialize_snapshot(snapshot_data)

	# TODO: Sanitize

	var merged := RollbackHistoryServer.merge_snapshot(snapshot)
	_logger.debug("Merged input; %s", [merged])

@rpc("any_peer", "call_remote", "unreliable")
func _submit_state(snapshot_data: Variant):
	var snapshot := _deserialize_snapshot(snapshot_data)

	# TODO: Sanitize

	var merged := RollbackHistoryServer.merge_snapshot(snapshot)
	_logger.debug("Merged state; %s", [merged])
