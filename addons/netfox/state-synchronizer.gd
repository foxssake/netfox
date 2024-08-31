extends Node
class_name StateSynchronizer

## Synchronizes state from authority.

@export var root: Node
@export var properties: Array[String]

var _property_cache: PropertyCache
var _props: Array[PropertyEntry]

var _last_received_tick: int = -1
var _last_received_state: Dictionary = {}
var _sent_full_state_to_peer_ids: Array[int] = []

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_property_cache = PropertyCache.new(root)
	_props = []

	for property in properties:
		var pe = _property_cache.get_entry(property)
		_props.push_back(pe)

func _ready():
	process_settings()
	NetworkTime.after_tick.connect(_after_tick)

func _after_tick(_dt: float, tick: int):
	if is_multiplayer_authority():
		# Submit snapshot
		var local_state: Dictionary = PropertySnapshot.extract(_props)
		var properties_to_include: Array[String] = determine_properties_to_include(local_state)
	
		update_last_state_cache(local_state, tick)

		var state_to_broadcast: Dictionary = {}
		if (NetworkRollback.enable_state_diffs):
			#Set property values which are different from previous state sent
			for picked_property in properties_to_include:
				state_to_broadcast[picked_property] = local_state[picked_property]
		else:
			state_to_broadcast = local_state

		if (NetworkRollback.enable_state_serialization):
			var serialized_current_state: PackedByteArray = PropertiesSerializer.serialize_state_properties(tick, state_to_broadcast, properties_to_include, _props)
				
			# Broadcast as new state
			for picked_peer_id in multiplayer.get_peers():
				if (_sent_full_state_to_peer_ids.has(picked_peer_id)):
					_submit_serialized_state.rpc_id(picked_peer_id, serialized_current_state)
				else:
					var all_properties: Array[String] = []
					for picked_property_path in local_state:
						all_properties.append(picked_property_path)
					
					var serialized_full_state: PackedByteArray = PropertiesSerializer.serialize_state_properties(tick, local_state, all_properties, _props)
					_submit_serialized_state.rpc_id(picked_peer_id, serialized_full_state)
					_sent_full_state_to_peer_ids.append(picked_peer_id)
				
		else:
			for picked_peer_id in multiplayer.get_peers():
				if (_sent_full_state_to_peer_ids.has(picked_peer_id)):
					_submit_state.rpc_id(picked_peer_id, state_to_broadcast, tick)
				else:
					_submit_state.rpc_id(picked_peer_id, local_state, tick)
					_sent_full_state_to_peer_ids.append(picked_peer_id)
	else:
		# Apply last received state
		PropertySnapshot.apply(_last_received_state, _property_cache)

func determine_properties_to_include(new_state: Dictionary) -> Array[String]:
	var properties_to_include: Array[String] = []
	if (NetworkRollback.enable_state_diffs):
		if (_last_received_state.is_empty() == false):
			for picked_property_path in new_state:
				if (_last_received_state.has(picked_property_path) == false):
					continue
					
				#If different value, include it in broadcasting state
				if (_last_received_state[picked_property_path] != new_state[picked_property_path]):
					properties_to_include.append(picked_property_path)
						
	return properties_to_include

@rpc("authority", "unreliable", "call_remote")
func _submit_serialized_state(serialized_state: PackedByteArray):
	var received_tick: int = serialized_state.decode_u32(0)
	var state_values_size: int = serialized_state.decode_u8(4)
	var header_property_indexes_contained: int = serialized_state.decode_u16(6)
	var serialized_state_values: PackedByteArray = serialized_state.slice(10, 10 + state_values_size)
	var deserialized_state: Dictionary = PropertiesSerializer.deserialize_state_properties(serialized_state_values, _props, header_property_indexes_contained)
	
	_submit_state(deserialized_state, received_tick)

@rpc("authority", "unreliable", "call_remote")
func _submit_state(received_state: Dictionary, tick: int):
	if tick <= _last_received_tick:
		return
		
	#Missing properties means they didn't change from previous tick
	#so, set it as the previous one (extrapolation)
	for picked_property_path in properties:
		if (received_state.has(picked_property_path) == false):
			if (_last_received_state.has(picked_property_path)):
				received_state[picked_property_path] = _last_received_state[picked_property_path]
			#else:
				#_logger.error("State synchronizer diff error, previous state has no property value, nor the received value. For property %s" % picked_property_path)
		
	update_last_state_cache(received_state, tick)
func update_last_state_cache(state: Dictionary, tick: int):
	_last_received_state = state
	_last_received_tick = tick
