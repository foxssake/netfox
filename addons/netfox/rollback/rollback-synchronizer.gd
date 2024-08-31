extends Node
class_name RollbackSynchronizer

## Similar to [MultiplayerSynchronizer], this class is responsible for
## synchronizing data between players, but with support for rollback.

@export var root: Node = get_parent()
@export var state_properties: Array[String]

@export_subgroup("Inputs")
@export var input_properties: Array[String]

## This will broadcast input to all peers, turning this off will limit to sending it to the server only.
## Turning this off is recommended to save bandwidth and reduce cheating risks.
@export var enable_input_broadcast: bool = true


var _record_state_props: Array[PropertyEntry] = []
var _record_input_props: Array[PropertyEntry] = []
var _auth_state_props: Array[PropertyEntry] = []
var _auth_input_props: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _states: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _inputs: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _serialized_inputs: Dictionary = {} #<tick, PackedByteArray>
var _serialized_states: Dictionary = {} #<tick, PackedByteArray>
var _serialized_inputs_to_send: Array[PackedByteArray] = []
var _latest_state: int = -1
var _earliest_input: int
var _sent_full_state_to_peer_ids: Array[int] = []

var _property_cache: PropertyCache
var _freshness_store: RollbackFreshnessStore

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("RollbackSynchronizer")

## Process settings.
##
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings():
	_property_cache = PropertyCache.new(root)
	_freshness_store = RollbackFreshnessStore.new()
	
	_nodes.clear()
	_record_state_props.clear()
	
	_states.clear()
	_inputs.clear()
	_serialized_inputs.clear()
	_serialized_states.clear()
	
	_latest_state = NetworkTime.tick - 1
	_earliest_input = NetworkTime.tick

	# Gather state props - all state props are recorded
	for property in state_properties:
		var pe: PropertyEntry = _property_cache.get_entry(property)
		_record_state_props.push_back(pe)
	
	process_authority()
	
	# Gather all rollback-aware nodes to simulate during rollbacks
	_nodes = root.find_children("*")
	_nodes.push_front(root)
	_nodes = _nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))
	_nodes.erase(self)

## Process settings based on authority.
##
## Call this whenever the authority of any of the nodes managed by
## RollbackSynchronizer changes. Make sure to do this at the same time on all 
## peers.
func process_authority():
	_record_input_props.clear()
	_auth_input_props.clear()
	_auth_state_props.clear()
	
	# Gather state properties that we own
	# i.e. it's the state of a node that belongs to the local peer
	for property in state_properties:
		var pe: PropertyEntry = _property_cache.get_entry(property)
		if pe.node.is_multiplayer_authority():
			_auth_state_props.push_back(pe)

	# Gather input properties that we own
	# Only record input that is our own
	for property in input_properties:
		var pe = _property_cache.get_entry(property)
		_record_input_props.push_back(pe)
		if pe.node.is_multiplayer_authority():
			_auth_input_props.push_back(pe)

func _ready():
	process_settings()
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	_latest_state = NetworkTime.tick - 1
	
	NetworkTime.before_tick.connect(_before_tick)
	NetworkTime.after_tick.connect(_after_tick)
	
	NetworkRollback.before_loop.connect(_before_loop)
	NetworkRollback.on_prepare_tick.connect(_prepare_tick)
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkRollback.on_record_tick.connect(_record_tick)
	NetworkRollback.after_loop.connect(_after_loop)

func _before_loop():
	if _auth_input_props.is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_resimulation_start(_earliest_input)
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_resimulation_start(_latest_state)

func _prepare_tick(tick: int):
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var state: Dictionary = _get_history(_states, tick)
	var input: Dictionary = _get_history(_inputs, tick)
	
	PropertySnapshot.apply(state, _property_cache)
	PropertySnapshot.apply(input, _property_cache)
	
	for node in _nodes:
		if _can_simulate(node, tick):
			NetworkRollback.notify_simulated(node)

func _can_simulate(node: Node, tick: int) -> bool:
	if node.is_multiplayer_authority():
		# Simulate from earliest input
		# Don't simulate frames we don't have input for
		return tick >= _earliest_input and _inputs.has(tick)
	else:
		# Simulate ONLY if we have state from server
		# Simulate from latest authorative state - anything the server confirmed we don't rerun
		# Don't simulate frames we don't have input for
		return tick >= _latest_state and _inputs.has(tick)

func _process_tick(tick: int):
	# Simulate rollback tick
	#	Method call on rewindables
	#	Rollback synchronizers go through each node they manage
	#	If current tick is in node's range, tick
	#		If authority: Latest input >= tick >= Latest state
	#		If not: Latest input >= tick >= Earliest input
	for node in _nodes:
		if NetworkRollback.is_simulated(node):
			var is_fresh = _freshness_store.is_fresh(node, tick)
			NetworkRollback.process_rollback(node, NetworkTime.ticktime, tick, is_fresh)
			_freshness_store.notify_processed(node, tick)



func _record_tick(tick: int):
	# Broadcast state we own
	if not _auth_state_props.is_empty(): #This is always the server, as the server owns all avatars
		var full_state_to_broadcast = {}
		
		for property in _auth_state_props:
			if _can_simulate(property.node, tick - 1):
				# Only broadcast if we've simulated the node
				full_state_to_broadcast[property.to_string()] = property.get_value()
	
		if full_state_to_broadcast.size() > 0:
			_latest_state = max(_latest_state, tick)
			_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), full_state_to_broadcast)
			
			var properties_to_include: Array[String] = []
			var diff_state_to_broadcast = {}
			if (NetworkRollback.enable_state_diffs):
				if (_states.has(tick - 1)):
					for picked_property_path in full_state_to_broadcast:
						if (_states[tick - 1].has(picked_property_path) == false):
							continue
							
						#If different value, include it in broadcasting state
						if (_states[tick - 1][picked_property_path] != full_state_to_broadcast[picked_property_path]):
							properties_to_include.append(picked_property_path)

					#Set property values which are different from previous state sent
					for picked_property in properties_to_include:
						diff_state_to_broadcast[picked_property] = full_state_to_broadcast[picked_property]
			
			_attempt_submit_serialized_states(tick, full_state_to_broadcast, diff_state_to_broadcast, properties_to_include)
	
	# Record state for specified tick ( current + 1 )
	if not _record_state_props.is_empty() and tick > _latest_state:
		_states[tick] = PropertySnapshot.extract(_record_state_props)

func _after_loop():
	_earliest_input = NetworkTime.tick
	# Apply display state
	var display_state = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset)
	PropertySnapshot.apply(display_state, _property_cache)

func _before_tick(_delta, tick):
	# Apply state for tick
	var state = _get_history(_states, tick)
	PropertySnapshot.apply(state, _property_cache)

func _after_tick(_delta: float, _tick: int):
	if not _auth_input_props.is_empty():
		var local_input: Dictionary = PropertySnapshot.extract(_auth_input_props)
		_inputs[_tick] = local_input
			
		if (NetworkRollback.enable_input_serialization):
			var serialized_current_input: PackedByteArray = PropertiesSerializer.serialize_input_properties(_auth_input_props, _tick)
			_serialized_inputs[_tick] = serialized_current_input
			
			if (_serialized_inputs_to_send.size() == NetworkRollback.input_redundancy):
				_serialized_inputs_to_send.remove_at(0)
			_serialized_inputs_to_send.append(serialized_current_input)
			
			if (_serialized_inputs_to_send.is_empty() == false):
				var merged_serialized_inputs: PackedByteArray
				merged_serialized_inputs.resize(0)
				for picked_serialized_input in _serialized_inputs_to_send:
					merged_serialized_inputs.append_array(picked_serialized_input)

				_attempt_submit_serialized_inputs(merged_serialized_inputs)
		else:
			#Send the last n inputs for each property
			var inputs = {}
			for i in range(0, NetworkRollback.input_redundancy):
				var tick_input: Dictionary = _inputs.get(_tick - i, {})
				for property in tick_input:
					if not inputs.has(property):
						inputs[property] = []
					inputs[property].push_back(tick_input[property])

			_attempt_submit_raw_input(inputs)
		
	history_cleanup()
func history_cleanup() -> void:
	while _states.size() > NetworkRollback.history_limit:
		_states.erase(_states.keys().min())
	
	while _inputs.size() > NetworkRollback.history_limit:
		_inputs.erase(_inputs.keys().min())
		
	if (NetworkRollback.enable_input_serialization):
		if (NetworkRollback.serialized_inputs_history_limit > 0):
			while _serialized_inputs.size() > NetworkRollback.serialized_inputs_history_limit:
				#Would be faster if we cached the earliest key in an integer instead of searching min() each tick!
				_serialized_inputs.erase(_serialized_inputs.keys().min())
		
	if (NetworkRollback.enable_state_serialization):
		if (NetworkRollback.serialized_states_history_limit > 0):
			while _serialized_states.size() > NetworkRollback.serialized_states_history_limit:
				#Would be faster if we cached the earliest key in an integer instead of searching min() each tick!
				_serialized_states.erase(_serialized_states.keys().min())
		
	_freshness_store.trim()

## Sends batched inputs to all other players (not local!)
func _attempt_submit_raw_input(batched_inputs: Dictionary):
	# TODO: Default to input broadcast in mesh network setups
	if enable_input_broadcast:
		for picked_peer_id in multiplayer.get_peers():
			_submit_raw_input.rpc_id(picked_peer_id, batched_inputs, NetworkTime.tick)
	elif not multiplayer.is_server():
		_submit_raw_input.rpc_id(1, batched_inputs, NetworkTime.tick)

## Sends serialized batched inputs to all other players (not local!)
func _attempt_submit_serialized_inputs(serialized_inputs: PackedByteArray):
	# TODO: Default to input broadcast in mesh network setups
	if enable_input_broadcast:
		for picked_peer_id in multiplayer.get_peers():
			_submit_serialized_inputs.rpc_id(picked_peer_id, serialized_inputs)
	elif not multiplayer.is_server():
		_submit_serialized_inputs.rpc_id(1, serialized_inputs)

func _attempt_submit_serialized_states(tick: int, full_state_to_broadcast: Dictionary, diff_state_to_broadcast: Dictionary, properties_to_include: Array[String]):
	if (NetworkRollback.enable_state_serialization):
		var serialized_current_state: PackedByteArray = PropertiesSerializer.serialize_state_properties(tick, diff_state_to_broadcast, properties_to_include, _auth_state_props)
		_serialized_states[tick] = serialized_current_state
		
		# Broadcast as new state
		for picked_peer_id in multiplayer.get_peers():
			if (_sent_full_state_to_peer_ids.has(picked_peer_id) && diff_state_to_broadcast.is_empty() == false):
				_submit_serialized_state.rpc_id(picked_peer_id, serialized_current_state)
			else: #First state must be the full state
				var all_properties: Array[String] = []
				for picked_property_path in full_state_to_broadcast:
					all_properties.append(picked_property_path)
				
				var serialized_full_state: PackedByteArray = PropertiesSerializer.serialize_state_properties(tick, full_state_to_broadcast, all_properties, _auth_state_props)
				_submit_serialized_state.rpc_id(picked_peer_id, serialized_full_state)
				_sent_full_state_to_peer_ids.append(picked_peer_id)
	else:
		# Broadcast as new state
		for picked_peer_id in multiplayer.get_peers():
			if (_sent_full_state_to_peer_ids.has(picked_peer_id) && diff_state_to_broadcast.is_empty() == false):
				_submit_state.rpc_id(picked_peer_id, diff_state_to_broadcast, tick)
			else: #First state must be full
				_submit_state.rpc_id(picked_peer_id, full_state_to_broadcast, tick)
				_sent_full_state_to_peer_ids.append(picked_peer_id)

func _get_history(buffer: Dictionary, tick: int) -> Dictionary:
	if buffer.has(tick):
		return buffer[tick]

	if buffer.is_empty():
		return {}
	
	var earliest: int = buffer.keys().min()
	var latest: int = buffer.keys().max()

	if tick < earliest:
		return buffer[earliest]
	
	if tick > latest:
		return buffer[latest]
	
	var before = buffer.keys() \
		.filter(func (key): return key < tick) \
		.max()
	
	return buffer[before]

@rpc("any_peer", "unreliable", "call_remote")
func _submit_serialized_inputs(serialized_inputs: PackedByteArray):
	var sender: int = multiplayer.get_remote_sender_id()
	
	#TODO: Security check to ensure no other client sent this (when enable_input_broadcast == false), see sanitization in submit_raw_inputs
	
	var picked_tick: int
	var picked_input_values_size: int #The size of the serialized input containing all properties (excluding tick timestamp[0,1,2,3] and the size itself on byte[4])
	var picked_single_input: PackedByteArray
	var picked_byte_index: int = 0
	while (picked_byte_index < serialized_inputs.size()):
		picked_tick = serialized_inputs.decode_u32(picked_byte_index)
		picked_byte_index += 4
		picked_input_values_size = serialized_inputs.decode_u8(picked_byte_index)
		picked_byte_index += 1

		if (_inputs.has(picked_tick) == false): #New input!
			picked_single_input = serialized_inputs.slice(picked_byte_index, picked_byte_index + picked_input_values_size)
			var received_properties: Dictionary
			if (_auth_input_props.is_empty()):
				received_properties = PropertiesSerializer.deserialize_input_properties(picked_single_input, _record_input_props)
			else:
				received_properties = PropertiesSerializer.deserialize_input_properties(picked_single_input, _auth_input_props)
			
			_earliest_input = min(_earliest_input, picked_tick)
			
			if (_inputs.has(picked_tick) == false):
				_inputs[picked_tick] = received_properties
			else:
				for picked_property_path in received_properties:
					_inputs[picked_tick][picked_property_path] = received_properties[picked_property_path]


		picked_byte_index += picked_input_values_size
	
@rpc("any_peer", "unreliable", "call_remote")
func _submit_raw_input(input: Dictionary, tick: int):
	var sender: int = multiplayer.get_remote_sender_id()
	
	var sanitized = {}
	for property in input:
		var pe: PropertyEntry = _property_cache.get_entry(property)
		var value = input[property]
		var input_owner: int = pe.node.get_multiplayer_authority()
		
		if input_owner != sender:
			_logger.warning("Received input for node owned by %s from %s, sender has no authority!" \
				% [input_owner, sender])
			continue
		
		sanitized[property] = value
	
	if sanitized.size() > 0:
		for property in sanitized:
			for i in range(0, sanitized[property].size()):
				var t = tick - i
				var old_input = _inputs.get(t, {}).get(property)
				var new_input = sanitized[property][i]
				
				if old_input == null:
					# We received an array of current and previous inputs, merge them into our history.
					_inputs[t] = _inputs.get(t, {})
					_inputs[t][property] = new_input
					_earliest_input = min(_earliest_input, t)
	else:
		_logger.warning("Received invalid input from %s for tick %s for %s" % [sender, tick, root.name])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_serialized_state(serialized_state: PackedByteArray):
	var received_tick: int = serialized_state.decode_u32(0)
	var state_values_size: int = serialized_state.decode_u16(4)
	var header_property_indexes_contained: int = serialized_state.decode_u16(6)
	var serialized_state_values: PackedByteArray = serialized_state.slice(10, 10 + state_values_size)
	var deserialized_state_of_this_tick: Dictionary
	
	deserialized_state_of_this_tick = PropertiesSerializer.deserialize_state_properties(serialized_state_values, _record_state_props, header_property_indexes_contained)
	
	_submit_state(deserialized_state_of_this_tick, received_tick)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_state(received_state: Dictionary, tick: int):
	if tick > NetworkTime.tick:
		# This used to be weird, but is now expected due to estimating remote time
		# push_warning("Received state from the future %s / %s - adding nonetheless" % [tick, NetworkTime.tick])
		pass
	
	if tick < NetworkTime.tick - NetworkRollback.history_limit and _latest_state >= 0:
		# State too old!
		_logger.error("Received state for %s, rejecting because older than %s frames" % [tick, NetworkRollback.history_limit])
		return

	var sender: int = multiplayer.get_remote_sender_id()
	var sanitized = {}
	for property in received_state:
		var pe: PropertyEntry = _property_cache.get_entry(property)
		var value = received_state[property]
		var state_owner: int = pe.node.get_multiplayer_authority()
		
		if state_owner != sender:
			_logger.warning("Received state for node owned by %s from %s, sender has no authority!" \
				% [state_owner, sender])
			continue
			
		sanitized[property] = value
		
	#Missing properties means they didn't change from previous tick
	#so, set it as the previous one (extrapolation)
	for picked_property_path in state_properties:
		if (sanitized.has(picked_property_path) == false):
			if (_states.has(tick - 1)):
				if (_states[tick-1].has(picked_property_path)):
					sanitized[picked_property_path] = _states[tick - 1][picked_property_path]
				else:
					_logger.error("Diff states error, _states of previous tick %s, doesn't have property %s" % [tick -1, picked_property_path])
			else:
				_logger.error("Diff states error, current tick is %s and _states doesn't have previous tick %s" % [tick, tick - 1])
	
	if sanitized.size() > 0:
		_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), sanitized)
		_latest_state = tick
	else:
		_logger.warning("Received invalid state from %s for tick %s" % [sender, tick])
