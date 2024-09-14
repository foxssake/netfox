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

## Unlike state diffs which apply project-wide, input-diffs are often undesired because they have a performance cost
## because at each receival, there is a forloop to check against every property. And this forloop is for every player input received!
## This is often needless for inputs, because in most games, inputs are different (movement + aim/mouse position)
## Set to true if you have many input properties which are not updated often.
## Set to false if your input properties are few and often update (see forest-brawl example, being movement and mouse position)
#@export var enable_input_diffs: bool = false

var _record_state_props: Array[PropertyEntry] = []
var _record_input_props: Array[PropertyEntry] = []
var _auth_state_props: Array[PropertyEntry] = []
var _auth_input_props: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _states: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _inputs: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _latest_state: int = -1
var _earliest_input: int

var _batched_inputs_to_broadcast: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _sent_full_state_to_peer_ids: Array[int] = []
var _sent_full_input_to_peer_ids: Array[int] = []
var _has_received_full_state: bool = false

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
	var picked_property_entry: PropertyEntry
	for picked_property in state_properties:
		picked_property_entry = _property_cache.get_entry(picked_property)
		if picked_property_entry.node.is_multiplayer_authority():
			_auth_state_props.push_back(picked_property_entry)

	# Gather input properties that we own
	# Only record input that is our own
	for picked_property in input_properties:
		picked_property_entry = _property_cache.get_entry(picked_property)
		_record_input_props.push_back(picked_property_entry)
		if picked_property_entry.node.is_multiplayer_authority():
			_auth_input_props.push_back(picked_property_entry)
	

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
			var is_fresh: bool = _freshness_store.is_fresh(node, tick)
			NetworkRollback.process_rollback(node, NetworkTime.ticktime, tick, is_fresh)
			_freshness_store.notify_processed(node, tick)

func _record_tick(tick: int):
	# Broadcast state we own
	if not _auth_state_props.is_empty(): #This is always the server, as the server owns all avatars
		var full_state_to_broadcast: Dictionary = {}

		for property in _auth_state_props:
			if _can_simulate(property.node, tick - 1):
				# Only broadcast if we've simulated the node
				full_state_to_broadcast[property.to_string()] = property.get_value()
	
		if full_state_to_broadcast.size() > 0:
			# Broadcast as new state
			_latest_state = max(_latest_state, tick)
			_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), full_state_to_broadcast)
			
			if (NetworkRollback.enable_state_diffs == false || _states.has(tick - 1) == false):
				_submit_state.rpc(full_state_to_broadcast, tick)
			else:
				var properties_to_include: Array[String] = []
				var diff_state_to_broadcast: Dictionary = {}
				for picked_property_path in full_state_to_broadcast:
					#If previous tick doesnt have a property, this means its a new property added in runtime, so we must add it.
					if (_states[tick - 1].has(picked_property_path) == false):
						properties_to_include.append(picked_property_path)
					#If different value, include it in broadcasting state
					elif (_states[tick - 1][picked_property_path] != full_state_to_broadcast[picked_property_path]):
						properties_to_include.append(picked_property_path)

				#Set property values which are different from previous state sent
				for picked_property in properties_to_include:
					diff_state_to_broadcast[picked_property] = full_state_to_broadcast[picked_property]
			
				#print("At tick %s sent diff state which is: %s " % [tick, diff_state_to_broadcast])
			
				for picked_peer_id in multiplayer.get_peers():
					#If the client has received the full state, we can start sending diff states
					if (_sent_full_state_to_peer_ids.has(picked_peer_id)):
						_submit_state.rpc_id(picked_peer_id, diff_state_to_broadcast, tick)
					else: #send full state containing all properties
						_submit_state.rpc_id(picked_peer_id, full_state_to_broadcast, tick)
	
	# Record state for specified tick ( current + 1 )
	if not _record_state_props.is_empty() and tick > _latest_state:
		_states[tick] = PropertySnapshot.extract(_record_state_props)

func _after_loop():
	_earliest_input = NetworkTime.tick
	
	# Apply display state
	var display_state: Dictionary = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset)
	PropertySnapshot.apply(display_state, _property_cache)

func _before_tick(_delta: float, tick: int):
	# Apply state for tick
	var state: Dictionary = _get_history(_states, tick)
	PropertySnapshot.apply(state, _property_cache)

func _after_tick(_delta: float, _tick: int):
	if not _auth_input_props.is_empty():
		var local_input = PropertySnapshot.extract(_auth_input_props)
		_inputs[NetworkTime.tick] = local_input

		if (_batched_inputs_to_broadcast.size() == NetworkRollback.input_redundancy):
			_batched_inputs_to_broadcast.erase(_batched_inputs_to_broadcast.keys().min())
		_batched_inputs_to_broadcast[_tick] = local_input

		_attempt_submit_inputs(_batched_inputs_to_broadcast)
	

	while _states.size() > NetworkRollback.history_limit:
		_states.erase(_states.keys().min())
	
	while _inputs.size() > NetworkRollback.history_limit:
		_inputs.erase(_inputs.keys().min())
		
	_freshness_store.trim()

## Sends batched inputs to all other players (not local!)
func _attempt_submit_inputs(batched_inputs: Dictionary):
	# TODO: Default to input broadcast in mesh network setups
	if enable_input_broadcast:
		_submit_inputs.rpc(batched_inputs, NetworkTime.tick)
	elif not multiplayer.is_server():
		_submit_inputs.rpc_id(1, batched_inputs, NetworkTime.tick)

func _get_history(buffer: Dictionary, tick: int) -> Dictionary:
	if buffer.has(tick):
		return buffer[tick]

	if buffer.is_empty():
		return {}
	
	var earliest: int = buffer.keys().min()
	var latest: int = buffer.keys().max()

	if tick < earliest:
		return buffer[earliest]
	
	#For inputs, this is extrapolation aka prediction
	#For example, if you move to the right (at latest)
	#at tick, you will still be moving to the right ;)
	if tick > latest:
		return buffer[latest]
	
	var before: int = buffer.keys() \
		.filter(func (key): return key < tick) \
		.max()
	
	return buffer[before]

@rpc("any_peer", "unreliable", "call_remote")
func _submit_inputs(inputs: Dictionary, tick: int):
	var sender_id: int = multiplayer.get_remote_sender_id()
	var sanitized: Dictionary = {}

	for picked_tick in inputs:
		sanitized[picked_tick] = {}
		for property in inputs[picked_tick]:
			var pe: PropertyEntry = _property_cache.get_entry(property)
			var value = inputs[picked_tick][property]
			var input_owner: int = pe.node.get_multiplayer_authority()

			if input_owner != sender_id:
				_logger.warning("Received input for node owned by %s from %s, sender has no authority!" \
					% [input_owner, sender_id])
				continue

			sanitized[picked_tick][property] = value
	
	if sanitized.size() > 0:
		for picked_tick in sanitized:
			var old_input: Dictionary = _inputs.get(picked_tick, {})
			if (old_input.is_empty()): #New input! Merge it into our history
				_inputs[picked_tick] = sanitized[picked_tick]
				_earliest_input = min(_earliest_input, picked_tick)
	else:
		_logger.warning("Received invalid input from %s for tick %s for %s" % [sender_id, tick, root.name])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_state(received_state: Dictionary, tick: int):
	if tick < NetworkTime.tick - NetworkRollback.history_limit and _latest_state >= 0:
		# State too old!
		_logger.error("Received state for %s, rejecting because older than %s frames" % [tick, NetworkRollback.history_limit])
		return

	# It is guaranteed that the first states are full, until the client sends acks to the server
	# which enables the server to start sending diffs
	if (not _has_received_full_state):
		_has_received_full_state = true
		_receive_full_state_ack.rpc_id(1, tick)

	if (received_state.size() > 0):
		set_received_state(received_state, tick, multiplayer.get_remote_sender_id())
	elif (NetworkRollback.enable_state_diffs):
		_states[tick] = _states[tick - 1]
		_latest_state = tick
	else:
		_logger.error("At tick %s Received a state without any properties, but diff states which should make it possible, are disabled!" % tick)
	
func set_received_state(received_state: Dictionary, tick: int, sender_id: int):
	var sanitized: Dictionary = {}
	var missing_property: bool = false
	for property_entry in _record_state_props:
		var state_owner_id: int = property_entry.node.get_multiplayer_authority()
		if state_owner_id != sender_id:
			_logger.warning("Received state for node owned by %s from %s, sender has no authority!" \
				% [state_owner_id, sender_id])
			continue
			
		if (received_state.has(property_entry._path) == false):
			missing_property = true
			continue
		
		var value = received_state[property_entry._path]
		sanitized[property_entry._path] = value
	
	## Detect if new property is added on runtime and sent
	var new_property: bool = false
	for property in received_state:
		for property_entry in _record_state_props:
			if (property_entry._path == property):
				continue
		new_property = true
		break
	
	
	if (NetworkRollback.enable_state_diffs && missing_property):
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
		_logger.warning("Received invalid state from %s for tick %s" % [sender_id, tick])

## Once the server receives acknowledgement from the client that it has received a full state
## (hence its possible to get the values of future properties whose values are the same, without the server sending them)
## then it starts sending diff states.
@rpc("any_peer", "reliable", "call_remote")
func _receive_full_state_ack(tick: int):
	if (_sent_full_state_to_peer_ids.has(multiplayer.get_remote_sender_id())):
		return
	_sent_full_state_to_peer_ids.append(multiplayer.get_remote_sender_id())
