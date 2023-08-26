@icon("./icons/RollbackSynchronizer.svg")
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
##
## [i]Note[/i] that with interpolation enabled, it is recommended to add all
## state properties as interpolation properties too, otherwise you might get
## unexpected result. This may or may not change in the future.

class PropertyEntry:
	var _path: String
	var node: Node
	var property: String
	
	func get_value() -> Variant:
		return node.get(property)
	
	func set_value(value):
		node.set(property, value)
	
	func is_valid() -> bool:
		if node == null:
			return false
			
		if node.get(property) == null:
			return false
		
		return true
	
	func _to_string() -> String:
		return _path
	
	static func parse(root: Node, path: String) -> PropertyEntry:
		var result = PropertyEntry.new()
		result.node = root.get_node(NodePath(path))
		result.property = path.erase(0, path.find(":") + 1)
		result._path = path
		return result

@export var root: Node = get_parent()
@export var enable_interpolation: bool = true
@export var state_properties: Array[String]
@export var input_properties: Array[String]
@export var interpolate_properties: Array[String]

var _record_state_props: Array[PropertyEntry] = []
var _record_input_props: Array[PropertyEntry] = []
var _auth_state_props: Array[PropertyEntry] = []
var _auth_input_props: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _states = {}
var _inputs = {}
var _latest_state = -1
var _earliest_input = INF

var _lerp_before_loop = {}
var _lerp_from = {}
var _lerp_to = {}

var _pe_cache: Dictionary = {}

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_pe_cache.clear()
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
		var pe = _get_pe(property)
		_record_state_props.push_back(pe)
		if pe.node.is_multiplayer_authority():
			_auth_state_props.push_back(pe)

	for property in input_properties:
		var pe = _get_pe(property)
		if pe.node.is_multiplayer_authority():
			_record_input_props.push_back(pe)
			_auth_input_props.push_back(pe)
	
	for pe in _pe_cache.values():
		var node = pe.node as Node
		
		if not node.has_method("_tick"):
			continue
		
		if _nodes.has(node):
			continue

		_nodes.push_back(node)

## Check if interpolation can be done.
##
## Even if it's enabled, no interpolation will be done if there are no
## properties to interpolate.
func can_interpolate() -> bool:
	return enable_interpolation and not interpolate_properties.is_empty()

func _ready():
	process_settings()
	
	NetworkTime.after_tick.connect(_after_tick)
	NetworkRollback.before_loop.connect(_before_loop)
	NetworkRollback.on_prepare_tick.connect(_prepare_tick)
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkRollback.on_record_tick.connect(_record_tick)
	NetworkRollback.after_loop.connect(_after_loop)

func _process(delta):
	_interpolate(_lerp_from, _lerp_to, _lerp_before_loop, NetworkTime.tick_factor, delta)

func _before_loop():
	if _auth_input_props.is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_input_tick(_earliest_input)
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_input_tick(_latest_state)
	_lerp_before_loop = _extract(_record_state_props)
	
	var latest_input = _inputs.keys().max() if not _inputs.is_empty() else -1
	var latest_state = _latest_state
	var earliest_input = _earliest_input

func _prepare_tick(tick: int):
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var state = _get_history(_states, tick)
	var input = _get_history(_inputs, tick)
	
	_apply(state)
	_apply(input)

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
		if not _can_simulate(node, tick):
			continue

		node._tick(NetworkTime.ticktime, tick)

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
			_states[tick] = _merge(_states.get(tick, {}), broadcast)
			rpc("_submit_state", broadcast, tick)
	
	# Record state for specified tick ( current + 1 )
	if not _record_state_props.is_empty() and tick > _latest_state:
		_states[tick] = _extract(_record_state_props)

func _after_loop():
	_earliest_input = NetworkTime.tick
	
	var display_state = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset)
	_lerp_from = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset - 1)
	_lerp_to = display_state
	
	if can_interpolate():
		_apply(_lerp_before_loop)
	else:
		# Apply display state
		_apply(display_state)

func _after_tick(_delta, _tick):
	if not _auth_input_props.is_empty():
		var input = _extract(_auth_input_props)
		_inputs[NetworkTime.tick] = input
		rpc("_submit_input", input, NetworkTime.tick)
	
	while _states.size() > NetworkRollback.history_limit:
		_states.erase(_states.keys().min())
	
	while _inputs.size() > NetworkRollback.history_limit:
		_inputs.erase(_inputs.keys().min())

func _interpolate(from: Dictionary, to: Dictionary, loop: Dictionary, f: float, delta: float):
	if not can_interpolate():
		return

	for property in from:
		if not interpolate_properties.has(property): continue
		if not to.has(property): continue
		if not loop.has(property): continue
		
		var pe = _get_pe(property)
		var a = pe.get_value()
		var b = to[property]
		
		# The idea is to - instead of simply lerping between two states - move 
		# towards the target state, linearly. Thus, the factor for interpolation
		# is calculated based on our "distance" from the target state and how 
		# much time we have left to move towards it.
		#
		# This will always be linear, as the further we are into the current
		# tick, the distance to the target state will decrease at the same rate.
		var df = delta / ((1.0 - f) * NetworkTime.ticktime)
		
		if a is float:
			pe.set_value(move_toward(a, b, abs(a - b) * df))
		elif a is Vector2:
			pe.set_value((a as Vector2).move_toward(b, (a as Vector2).distance_to(b) * df))
		elif a is Vector3:
			pe.set_value((a as Vector3).move_toward(b, (a as Vector3).distance_to(b) * df))
		# TODO: Add as separate feature
		elif a is Transform2D:
			pe.set_value((a as Transform2D).interpolate_with(b, clamp(df, 0, 1)))
		elif a is Transform3D:
			pe.set_value((a as Transform3D).interpolate_with(b, clamp(df, 0, 1)))
		else:
			pe.set_value(a if f < 0.5 else b)

func _extract(properties: Array[PropertyEntry]) -> Dictionary:
	var result = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	result.make_read_only()
	return result

func _apply(properties: Dictionary):
	for property in properties:
		var pe = _get_pe(property)
		var value = properties[property]
		pe.set_value(value)

func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result = {}
	for key in a:
		result[key] = a[key]
	for key in b:
		result[key] = b[key]
	return result

func _get_pe(path: String) -> PropertyEntry:
	if not _pe_cache.has(path):
		var parsed = PropertyEntry.parse(root, path)
		if not parsed.is_valid():
			push_warning("Invalid property path: %s" % path)
		_pe_cache[path] = parsed
	return _pe_cache[path]

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
		var pe = _get_pe(property)
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

@rpc("any_peer", "reliable", "call_remote")
func _submit_state_reliable(state: Dictionary, tick: int):
	_submit_state(state, tick)

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
		var pe = _get_pe(property)
		var value = state[property]
		var state_owner = pe.node.get_multiplayer_authority()
		
		if state_owner != sender:
			push_warning("Received state for node owned by %s from %s, sender has no authority!" \
				% [state_owner, sender])
			continue
		
		sanitized[property] = value
	
	if sanitized.size() > 0:
		_states[tick] = _merge(_states.get(tick, {}), sanitized)
		_latest_state = max(_latest_state, tick)
	else:
		push_warning("Received invalid state from %s for tick %s" % [sender, tick])
