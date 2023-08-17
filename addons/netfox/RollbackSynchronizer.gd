@icon("./icons/RollbackSynchronizer.svg")
extends Node

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
var _last_reliable_broadcast = -1

var _lerp_before_loop = {}
var _lerp_from = {}
var _lerp_to = {}

var _pe_cache: Dictionary = {}

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

func _process_tick(tick: int):
	if _latest_state < 0 and _auth_state_props.is_empty():
		return

	var latest_input = _inputs.keys().max() if not _inputs.is_empty() else INF
	var latest_state = _latest_state
	var earliest_input = _earliest_input
	var broadcast_state = {}
	
	# Skip simulation if we don't have input
	if not _inputs.has(tick):
		return
	
	# Skip simulation if we already have an authorative frame
	if tick <= _latest_state:
		return

	# Simulate rollback tick
	#	Method call on rewindables
	#	Rollback synchronizers go through each node they manage
	#	If current tick is in node's range, tick
	#		If authority: Latest input >= tick >= Latest state
	#		If not: Latest input >= tick >= Earliest input
	for node in _nodes:
		if node.is_multiplayer_authority():
			if not (tick >= earliest_input and tick <= latest_input):
				continue
		else:
			if tick <= latest_state:
				continue
		
		# TODO: Notify whether this is a resimulated tick
		node._tick(NetworkTime.ticktime, tick)
		
		# Add simulated properties to broadcast state
		for property in _auth_state_props:
			if property.node == node:
				broadcast_state[property.to_string()] = property.get_value()
	
	if broadcast_state.size() > 0:
		_latest_state = max(_latest_state, tick)
		_states[tick] = _merge(_states.get(tick, {}), broadcast_state)
		rpc("_submit_state", broadcast_state, tick)

func _record_tick(tick: int):
	# Record state for specified tick ( current + 1 )
	if not _record_state_props.is_empty() and tick > _latest_state:
		# _states[tick] = _merge(_states.get(tick, {}), _extract(_record_state_props))
		_states[tick] = _extract(_record_state_props)

func _after_loop():
	_earliest_input = NetworkTime.tick
	
	var display_state = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset)
	_lerp_from = _get_history(_states, NetworkTime.tick - NetworkRollback.display_offset - 1)
	_lerp_to = display_state
	
	if enable_interpolation and not interpolate_properties.is_empty():
		_apply(_lerp_before_loop)
	else:
		# Apply display state
		_apply(display_state)
	
	if NetworkTime.tick - _last_reliable_broadcast > 8:
		if not _auth_state_props.is_empty():
			var last_reliable = _inputs.keys().max()
			if _states.has(last_reliable):
				rpc("_submit_state_reliable", _states[last_reliable], last_reliable)
		_last_reliable_broadcast = NetworkTime.tick

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
	if not enable_interpolation or interpolate_properties.is_empty():
		return

	for property in from:
		if not interpolate_properties.has(property): continue
		if not to.has(property): continue
		if not loop.has(property): continue
		
		var pe = _get_pe(property)
		var a = pe.get_value()
		var b = to[property]
		
		var df = delta / ((1.0 - f) * NetworkTime.ticktime)
		
		if a is float:
			pe.set_value(move_toward(a, b, abs(a - b) * df))
		elif a is Vector2:
			pe.set_value((a as Vector2).move_toward(b, (a as Vector2).distance_to(b) * df))
		elif a is Vector3:
			pe.set_value((a as Vector3).move_toward(b, (a as Vector3).distance_to(b) * df))
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
