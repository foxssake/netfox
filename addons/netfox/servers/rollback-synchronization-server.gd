extends Node
class_name _RollbackSynchronizationServer

# TODO: Support various encoders
# TODO: Diff states
# TODO: Honor visibility filters

var _input_properties: Array = []
var _state_properties: Array = []

var _full_state_interval := 24
var _state_ack_interval := 4
var _ackd_tick := {} # peer id to ack'd tick

static var _logger := NetfoxLogger._for_netfox("RollbackSynchronizationServer")

signal on_input(snapshot: Snapshot)
signal on_state(snapshot: Snapshot)

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
		input_snapshot._is_authoritative[property] = snapshot._is_authoritative[property]

	# Transmit
	# _logger.debug("Submitting input: %s", [input_snapshot])
	_submit_input.rpc(_serialize_snapshot(input_snapshot))

func synchronize_state(tick: int) -> void:
	# Grab snapshot from RollbackHistoryServer
	var snapshot := RollbackHistoryServer.get_snapshot(tick)
	if not snapshot:
		return

	# Filter to state properties
	var state_snapshot := snapshot.filtered_to_properties(_state_properties)
	
	# Figure out whether to send full- or diff state
	var is_diff := false
	# TODO: Something better than modulo logic?
	if _full_state_interval >= 1 and (tick % _full_state_interval) != 0:
		is_diff = true

	# Transmit
	if is_diff:
		for peer in multiplayer.get_peers():
			if not _ackd_tick.has(peer):
				# We don't know any state the peer knows, send full state
				_submit_state.rpc_id(peer, _serialize_snapshot(state_snapshot))
				_logger.info("Sent full state for @%d to #%d", [tick, peer])
				continue

			var reference_tick := _ackd_tick[peer] as int
			var reference_snapshot := RollbackHistoryServer.get_snapshot(reference_tick)
			
			if not reference_snapshot:
				# Reference snapshot not in history, send full state
				_logger.warning("Tick @%d not present in history, can't use it as reference for peer #%d", [reference_tick, peer])
				_submit_state.rpc_id(peer, _serialize_snapshot(state_snapshot))
				_logger.info("Sent full state for @%d to #%d", [tick, peer])
				continue

			# TODO: Optimize, don't create two snapshots
			reference_snapshot = reference_snapshot.filtered_to_auth().filtered_to_properties(_state_properties)
			
			var diff_snapshot := Snapshot.make_patch(state_snapshot, reference_snapshot)
			_submit_state.rpc_id(peer, _serialize_snapshot(diff_snapshot))
#			_submit_state.rpc_id(peer, _serialize_snapshot(state_snapshot))
#			_logger.info("Sent diff state for @%d <- @%d to #%d", [tick, reference_tick, peer])
	else:
		# _logger.debug("Submitting state: %s", [state_snapshot])
		_submit_state.rpc(_serialize_snapshot(state_snapshot))
		_logger.info("Broadcast full state for @%d", [tick])

func _serialize_snapshot(snapshot: Snapshot) -> Variant:
	var serialized_properties := []

	for entry in snapshot.data.keys():
		var node := entry[0] as Node
		var property := entry[1] as NodePath
		var value = snapshot.data[entry]
		var is_auth := snapshot._is_authoritative.get(entry, false)

		if not is_auth:
			# Don't broadcast data we're not sure about
			continue

		serialized_properties.append([str(node.get_path()), str(property), value, is_auth])

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
		var is_auth := entry_data[3] as bool

		var node := get_tree().root.get_node(node_path)
		if not node:
			_logger.warning("Can't find node at path %s, ignoring", [node_path])
			continue

		snapshot.set_property(node, property, value, is_auth)
	
	return snapshot

@rpc("any_peer", "call_remote", "reliable")
func _submit_input(snapshot_data: Variant):
	var snapshot := _deserialize_snapshot(snapshot_data)
#	_logger.debug("Received input snapshot: %s", [snapshot])

	# TODO: Sanitize

	var merged := RollbackHistoryServer.merge_snapshot(snapshot)
#	_logger.debug("Merged input; %s", [merged])

	on_input.emit(snapshot)

@rpc("any_peer", "call_remote", "unreliable")
func _submit_state(snapshot_data: Variant):
	var sender := multiplayer.get_remote_sender_id()
	var snapshot := _deserialize_snapshot(snapshot_data)
	# TODO: Sanitize
#	_logger.debug("Received state snapshot: %s", [snapshot])

	var merged := RollbackHistoryServer.merge_snapshot(snapshot)
#	_logger.debug("Merged state; %s", [merged])

	if _state_ack_interval >= 1 and (snapshot.tick % _state_ack_interval) == 0:
		_ack_state.rpc_id(sender, snapshot.tick)

	on_state.emit(snapshot)

@rpc("any_peer", "call_remote", "unreliable")
func _ack_state(tick: int):
	var sender := multiplayer.get_remote_sender_id()
	_ackd_tick[sender] = maxi(tick, _ackd_tick.get(sender, tick))
