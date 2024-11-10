extends Node
class_name RollbackSynchronizer

## Similar to [MultiplayerSynchronizer], this class is responsible for
## synchronizing data between players, but with support for rollback.

@export var root: Node = get_parent()
@export var state_properties: Array[String]

@export_subgroup("Inputs")
@export var input_properties: Array[String]

## This will broadcast input to all peers, turning this off will limit to sending it to the server only.
## Turning this off is recommended to save bandwith and reduce cheating risks.
@export var enable_input_broadcast: bool = true

var _record_state_property_entries: Array[PropertyEntry] = []
var _record_input_property_entries: Array[PropertyEntry] = []
var _auth_state_property_entries: Array[PropertyEntry] = []
var _auth_input_property_entries: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _states: Dictionary = {}
var _inputs: Dictionary = {}
var _latest_state: int = -1
var _earliest_input: int

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
	_record_state_property_entries.clear()
	
	_states.clear()
	_inputs.clear()
	_latest_state = NetworkTime.tick - 1
	_earliest_input = NetworkTime.tick

	# Gather state properties - all state properties are recorded
	for property in state_properties:
		var property_entry = _property_cache.get_entry(property)
		_record_state_property_entries.push_back(property_entry)
	
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
	_record_input_property_entries.clear()
	_auth_input_property_entries.clear()
	_auth_state_property_entries.clear()
	
	# Gather state properties that we own
	# i.e. it's the state of a node that belongs to the local peer
	for property in state_properties:
		var property_entry = _property_cache.get_entry(property)
		if property_entry.node.is_multiplayer_authority():
			_auth_state_property_entries.push_back(property_entry)

	# Gather input properties that we own
	# Only record input that is our own
	for property in input_properties:
		var property_entry = _property_cache.get_entry(property)
		if property_entry.node.is_multiplayer_authority():
			_auth_input_property_entries.push_back(property_entry)
			_record_input_property_entries.push_back(property_entry)

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
	if _auth_input_property_entries.is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_resimulation_start(_earliest_input)
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_resimulation_start(_latest_state)

func _prepare_tick(tick: int):
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var state = _get_history(_states, tick)
	var input = _get_history(_inputs, tick)
	
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
	if not _auth_state_property_entries.is_empty():
		var broadcast = {}

		for property in _auth_state_property_entries:
			if _can_simulate(property.node, tick - 1):
				# Only broadcast if we've simulated the node
				broadcast[property.to_string()] = property.get_value()
	
		if broadcast.size() > 0:
			# Broadcast as new state
			_latest_state = max(_latest_state, tick)
			_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), broadcast)
			_submit_state.rpc(broadcast, tick)
	
	# Record state for specified tick ( current + 1 )
	if not _record_state_property_entries.is_empty() and tick > _latest_state:
		_states[tick] = PropertySnapshot.extract(_record_state_property_entries)

func _after_loop():
	_earliest_input = NetworkTime.tick
	
	# Apply display state
	var display_state = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset)
	PropertySnapshot.apply(display_state, _property_cache)

func _before_tick(_delta, tick):
	# Apply state for tick
	var state = _get_history(_states, tick)
	PropertySnapshot.apply(state, _property_cache)

func _after_tick(_delta, _tick):
	if not _record_input_property_entries.is_empty():
		var input = PropertySnapshot.extract(_record_input_property_entries)
		_inputs[NetworkTime.tick] = input

		#Send the last n inputs for each property 
		var inputs = {}
		for i in range(0, NetworkRollback.input_redundancy):
			var tick_input = _inputs.get(NetworkTime.tick - i, {})
			for property in tick_input:
				if not inputs.has(property):
					inputs[property] = []
				inputs[property].push_back(tick_input[property])

		_attempt_submit_input(inputs)
	
	while _states.size() > NetworkRollback.history_limit:
		_states.erase(_states.keys().min())
	
	while _inputs.size() > NetworkRollback.history_limit:
		_inputs.erase(_inputs.keys().min())
		
	_freshness_store.trim()

func _attempt_submit_input(input: Dictionary):
	# TODO: Default to input broadcast in mesh network setups
	if enable_input_broadcast:
		_submit_input.rpc(input, NetworkTime.tick)
	elif not multiplayer.is_server():
		_submit_input.rpc_id(1, input, NetworkTime.tick)

func _get_history(buffer: Dictionary, tick: int) -> Dictionary:
	if buffer.has(tick):
		return buffer[tick]

	if buffer.is_empty():
		return {}
	
	var earliest_tick = buffer.keys().min()
	var latest_tick = buffer.keys().max()

	if tick < earliest_tick:
		return buffer[earliest_tick]
	
	if tick > latest_tick:
		return buffer[latest_tick]
	
	var before = buffer.keys() \
		.filter(func (key): return key < tick) \
		.max()
	
	return buffer[before]

@rpc("any_peer", "unreliable", "call_remote")
func _submit_input(input: Dictionary, tick: int):
	var sender = multiplayer.get_remote_sender_id()
	var sanitized = {}
	for property in input:
		var property_entry = _property_cache.get_entry(property)
		var value = input[property]
		var input_owner = property_entry.node.get_multiplayer_authority()
		
		if input_owner != sender:
			_logger.warning("Received input for node owned by %s from %s, sender has no authority!" \
				% [input_owner, sender])
			continue
		
		sanitized[property] = value
	
	if sanitized.size() > 0:
		for property in sanitized:
			for i in range(0, sanitized[property].size()):
				var t = tick - i
				if t < NetworkTime.tick - NetworkRollback.history_limit:
					# Input too old
					_logger.error("Received input for %s, rejecting because older than %s frames" % [t, NetworkRollback.history_limit])
					continue

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
func _submit_state(state: Dictionary, tick: int):
	if tick > NetworkTime.tick:
		# This used to be weird, but is now expected due to estimating remote time
		# push_warning("Received state from the future %s / %s - adding nonetheless" % [tick, NetworkTime.tick])
		pass
	
	if tick < NetworkTime.tick - NetworkRollback.history_limit and _latest_state >= 0:
		# State too old!
		_logger.error("Received state for %s, rejecting because older than %s frames" % [tick, NetworkRollback.history_limit])
		return

	var sender = multiplayer.get_remote_sender_id()
	var sanitized = {}
	for property in state:
		var property_entry = _property_cache.get_entry(property)
		var value = state[property]
		var state_owner = property_entry.node.get_multiplayer_authority()
		
		if state_owner != sender:
			_logger.warning("Received state for node owned by %s from %s, sender has no authority!" \
				% [state_owner, sender])
			continue
		
		sanitized[property] = value
	
	if sanitized.size() > 0:
		_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), sanitized)
		# _latest_state = max(_latest_state, tick)
		_latest_state = tick
	else:
		_logger.warning("Received invalid state from %s for tick %s" % [sender, tick])
