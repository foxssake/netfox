extends Node
class_name RollbackSynchronizer

## Similar to [MultiplayerSynchronizer], this class is responsible for
## synchronizing data between players, but with support for rollback.

@export var root: Node = get_parent()

@export_group("State")
@export var state_properties: Array[String]
@export var full_state_interval: int = -1

@export_group("Inputs")
@export var input_properties: Array[String]

## This will broadcast input to all peers, turning this off will limit to sending it to the server only.
## Turning this off is recommended to save bandwidth and reduce cheating risks.
@export var enable_input_broadcast: bool = true

var _record_state_property_entries: Array[PropertyEntry] = []
var _record_input_property_entries: Array[PropertyEntry] = []
var _auth_state_property_entries: Array[PropertyEntry] = []
var _auth_input_property_entries: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _states: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _inputs: Dictionary = {} #<tick, Dictionary<String, Variant>>
var _latest_state_tick: int = -1
var _earliest_input: int

var _sent_full_state: Dictionary = {}
var _next_full_state: int

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
	_latest_state_tick = NetworkTime.tick - 1
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
		NetworkRollback.notify_resimulation_start(_latest_state_tick)

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
		return tick >= _latest_state_tick and _inputs.has(tick)

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
		var full_state: Dictionary = {}
		
		for property in _auth_state_property_entries:
			if _can_simulate(property.node, tick - 1):
				# Only broadcast if we've simulated the node
				full_state[property.to_string()] = property.get_value()

		if full_state.size() > 0:
			_latest_state_tick = max(_latest_state_tick, tick)
			_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), full_state)

			if not NetworkRollback.enable_state_diffs:
				# Broadcast new full state
				_submit_full_state.rpc(full_state, tick)
			elif full_state_interval > 0 and NetworkTime.tick > _next_full_state:
				# Send full state so we can send deltas from there
				_logger.debug("Broadcasting full state")
				_submit_full_state.rpc(full_state, tick)
				_next_full_state = NetworkTime.tick + full_state_interval
			else:
				for peer in multiplayer.get_peers():
					# Peer hasn't received a full state yet, can't send diffs
					if not _sent_full_state.has(peer):
						_submit_full_state.rpc_id(peer, full_state, tick)
						continue
					
					# History doesn't have reference tick?
					var reference_tick = _sent_full_state[peer]
					if not _states.has(reference_tick):
						_submit_full_state.rpc_id(peer, full_state, tick)
						continue
					
					# Prepare diff and send
					var reference_state = _get_history(_states, reference_tick)
					var diff_state = PropertySnapshot.diff(reference_state, full_state)
					
					if diff_state.size() == full_state.size():
						# State is completely different, send full state
						_submit_full_state.rpc_id(peer, full_state, tick)
					else:
						# Send only diff
						_submit_diff_state.rpc_id(peer, diff_state, tick, reference_tick)

	# Record state for specified tick ( current + 1 )
	if not _record_state_property_entries.is_empty() and tick > _latest_state_tick:
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
func _submit_full_state(state: Dictionary, tick: int):
	if tick < NetworkTime.tick - NetworkRollback.history_limit:
		# State too old!
		_logger.error("Received full state for %s, rejecting because older than %s frames" % [tick, NetworkRollback.history_limit])
		return

	var sender_id = multiplayer.get_remote_sender_id()
	var sanitized = {}

	for property_name in state:
		var property_entry = _property_cache.get_entry(property_name)
		var value = state[property_name]
		var state_owner_id = property_entry.node.get_multiplayer_authority()
		
		if state_owner_id != sender_id:
			_logger.warning("Received state for node owned by %s from %s, sender has no authority!" \
				% [state_owner_id, sender_id])
			continue
		
		sanitized[property_name] = value
	
	if sanitized.size() == 0:
		# State is completely invalid
		_logger.warning("Received invalid state from %s for tick %s" % [sender_id, tick])
		return

	_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), sanitized)
	_latest_state_tick = tick
		
	if NetworkRollback.enable_state_diffs:
		_receive_full_state_ack.rpc_id(get_multiplayer_authority(), tick)

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_diff_state(diff_state: Dictionary, tick: int, reference_tick: int):
	if tick < NetworkTime.tick - NetworkRollback.history_limit:
		# State too old!
		_logger.error("Received diff state for %s, rejecting because older than %s frames" % [tick, NetworkRollback.history_limit])
		return

	if not _states.has(reference_tick):
		# Reference tick missing, hope for the best
		_logger.warn("Reference tick %d missing for %d" % [reference_tick, tick])

	var reference_state = _states.get(reference_tick, {})

	if (diff_state.is_empty()):
		_latest_state_tick = _latest_state_tick
		_states[tick] = reference_state
	else:
		var sender_id = multiplayer.get_remote_sender_id()
		var sanitized = {}
		
		for property_name in diff_state:
			var pe = _property_cache.get_entry(property_name)
			var value = diff_state[property_name]
			var state_owner_id = pe.node.get_multiplayer_authority()
			
			if state_owner_id != sender_id:
				_logger.warning("Received state for node owned by %s from %s, sender has no authority!" \
					% [state_owner_id, sender_id])
				continue
			
			sanitized[property_name] = value

		if sanitized.size() > 0:
			_states[tick] = PropertySnapshot.merge(_states.get(tick, {}), sanitized)
			_latest_state_tick = tick
		else:
			_logger.warning("Received invalid state from %s for tick %s" % [sender_id, tick])

@rpc("any_peer", "reliable", "call_remote")
func _receive_full_state_ack(tick: int):
	var sender_id := multiplayer.get_remote_sender_id()
	_sent_full_state[sender_id] = tick
	
	_logger.debug("Peer %d ack'd full state for tick %d" % [sender_id, tick])
