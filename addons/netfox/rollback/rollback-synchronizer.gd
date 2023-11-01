extends Node
## Similar to [MultiplayerSynchronizer], this class is responsible for
## synchronizing data between players, but with support for rollback and
## interpolation.
##
## To do this, three types of properties need to be configured.
##
## The state properties describe the node's current game state. With regards to
## state, the server should be the sole authority, and their values are only
## predicted locally based on known inputs.
##
## The input properties are what drive the node's behaviour - for example, which
## direction is the player moving or aiming, is the player jumping, etc. With 
## this, always the controlling player is the one in control.
##
## Optionally, interpolated properties can also be configured, marking which
## properties should be interpolated.
##
## These properties are configured as node paths, relative to the configured
## root node.
##
## Since the rollback synchronizer needs to control ticks on a per-node basis,
## it did not make sense to provide a signal to which nodes can connect to.
## Instead, all the nodes who have a state property are checked for a "_tick"
## method, and if available, it will be called for tick (re)simulation.
##
## [i]Note[/i] that while most often we speak in terms of servers and clients,
## Netfox only deals with multiplayer authority, same as Godot itself. So, state
## is owned by whoever has the multiplayer authority over objects that contain
## state, and input is owned by whoever has the multiplayer authority over
## objects that contain inputs.
##
## [i]Note[/i] that while possible, it is currently not recommended to have
## state and input properties on the same object, since authority is then
## difficult to separate. Same for spreading state over multiple objects, each
## having different authority. This may or may not change in the future.

@export var root: Node = get_parent()
@export var state_properties: Array[String]
@export var input_properties: Array[String]
@export var simulate_nodes: Array[Node]

var _record_state_props: Array[PropertyEntry] = []
var _record_input_props: Array[PropertyEntry] = []
var _auth_state_props: Array[PropertyEntry] = []
var _auth_input_props: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _states = {}
var _inputs = {}
var _latest_state = -1
var _earliest_input = INF

var _property_cache: PropertyCache
var _freshness_store: RollbackFreshnessStore

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_property_cache = PropertyCache.new(root)
	_freshness_store = RollbackFreshnessStore.new()
	
	_nodes.clear()
	_record_input_props.clear()
	_record_state_props.clear()
	_auth_input_props.clear()
	_auth_state_props.clear()
	
	_states.clear()
	_inputs.clear()
	_latest_state = -1
	_earliest_input = NetworkTime.tick

	for property in state_properties:
		var pe = _property_cache.get_entry(property)
		_record_state_props.push_back(pe)
		if pe.node.is_multiplayer_authority():
			_auth_state_props.push_back(pe)

	for property in input_properties:
		var pe = _property_cache.get_entry(property)
		if pe.node.is_multiplayer_authority():
			_record_input_props.push_back(pe)
			_auth_input_props.push_back(pe)
	
	# Gather all nodes simulated ( unique )
	_nodes = []
	var all_nodes = _property_cache.properties()
	all_nodes = all_nodes.map(func(it): return it.node)
	all_nodes += simulate_nodes
	all_nodes = all_nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))

	for node in all_nodes:
		if not _nodes.has(node):
			_nodes.push_back(node)

func _ready():
	process_settings()
	
	NetworkTime.after_tick.connect(_after_tick)
	NetworkRollback.before_loop.connect(_before_loop)
	NetworkRollback.on_prepare_tick.connect(_prepare_tick)
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkRollback.on_record_tick.connect(_record_tick)
	NetworkRollback.after_loop.connect(_after_loop)

func _before_loop():
	if _auth_input_props.is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_input_tick(_earliest_input)
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_input_tick(_latest_state)
	
	var latest_input = _inputs.keys().max() if not _inputs.is_empty() else -1
	var latest_state = _latest_state
	var earliest_input = _earliest_input

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
	if not _auth_state_props.is_empty():
		var broadcast = {}

		for property in _auth_state_props:
			if _can_simulate(property.node, tick - 1):
				# Only broadcast if we've simulated the node
				broadcast[property.to_string()] = property.get_value()
	
		if broadcast.size() > 0:
			# Broadcast as new state
			_latest_state = max(_latest_state, tick)
			_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), broadcast)
			rpc("_submit_state", broadcast, tick)
	
	# Record state for specified tick ( current + 1 )
	if not _record_state_props.is_empty() and tick > _latest_state:
		_states[tick] = PropertySnapshot.extract(_record_state_props)

func _after_loop():
	_earliest_input = NetworkTime.tick
	
	# Apply display state
	var display_state = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset)
	PropertySnapshot.apply(display_state, _property_cache)

func _after_tick(_delta, _tick):
	if not _auth_input_props.is_empty():
		var input = PropertySnapshot.extract(_auth_input_props)
		_inputs[NetworkTime.tick] = input
		rpc("_submit_input", input, NetworkTime.tick)
	
	while _states.size() > NetworkRollback.history_limit:
		_states.erase(_states.keys().min())
	
	while _inputs.size() > NetworkRollback.history_limit:
		_inputs.erase(_inputs.keys().min())
		
	_freshness_store.trim()

func _get_history(buffer: Dictionary, tick: int) -> Dictionary:
	if buffer.has(tick):
		return buffer[tick]

	if buffer.is_empty():
		return {}
	
	var earliest = buffer.keys().min()
	var latest = buffer.keys().max()

	if tick < earliest:
		return buffer[earliest]
	
	if tick > latest:
		return buffer[latest]
	
	var before = buffer.keys() \
		.filter(func (key): return key < tick) \
		.max()
	
	return buffer[before]

@rpc("any_peer", "reliable", "call_remote")
func _submit_input(input: Dictionary, tick: int):
	var sender = multiplayer.get_remote_sender_id()
	var sanitized = {}
	for property in input:
		var pe = _property_cache.get_entry(property)
		var value = input[property]
		var input_owner = pe.node.get_multiplayer_authority()
		
		if input_owner != sender:
			push_warning("Received input for node owned by %s from %s, sender has no authority!" \
				% [input_owner, sender])
			continue
		
		sanitized[property] = value
	
	if sanitized.size() > 0:
		_inputs[tick] = sanitized
		_earliest_input = min(_earliest_input, tick)
	else:
		push_warning("Received invalid input from %s for tick %s for %s" % [sender, tick, root.name])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_state(state: Dictionary, tick: int):
	if tick > NetworkTime.tick:
		push_warning("Received state from the future %s / %s - adding nonetheless" % [tick, NetworkTime.tick])
	
	if tick < NetworkTime.tick - NetworkRollback.history_limit and _latest_state >= 0:
		# State too old!
		push_error("Received state for %s, rejecting because older than %s frames" % [tick, NetworkRollback.history_limit])
		return

	var sender = multiplayer.get_remote_sender_id()
	var sanitized = {}
	for property in state:
		var pe = _property_cache.get_entry(property)
		var value = state[property]
		var state_owner = pe.node.get_multiplayer_authority()
		
		if state_owner != sender:
			push_warning("Received state for node owned by %s from %s, sender has no authority!" \
				% [state_owner, sender])
			continue
		
		sanitized[property] = value
	
	if sanitized.size() > 0:
		_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), sanitized)
		# _latest_state = max(_latest_state, tick)
		_latest_state = tick
	else:
		push_warning("Received invalid state from %s for tick %s" % [sender, tick])
