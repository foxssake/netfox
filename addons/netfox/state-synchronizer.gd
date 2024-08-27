extends Node
class_name StateSynchronizer

## Synchronizes state from authority.

@export var root: Node
@export var properties: Array[String]

var _property_cache: PropertyCache
var _props: Array[PropertyEntry]

var _last_received_tick: int = -1
var _last_received_state: Dictionary = {}

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

func _after_tick(_dt, tick):
	if is_multiplayer_authority():
		# Submit snapshot
		var local_state: Dictionary = PropertySnapshot.extract(_props)
		update_last_state_cache(local_state, tick)

		if (NetworkRollback.enable_state_serialization):
			var serialized_current_state: PackedByteArray = PropertiesSerializer.serialize_multiple_properties(_props, tick)
				
			# Broadcast as new state
			for picked_peer_id in multiplayer.get_peers():
				_submit_serialized_state.rpc_id(picked_peer_id, serialized_current_state)
		else:
			for picked_peer_id in multiplayer.get_peers():
				_submit_state.rpc_id(picked_peer_id, local_state, tick)
	else:
		# Apply last received state
		PropertySnapshot.apply(_last_received_state, _property_cache)

@rpc("authority", "unreliable", "call_remote")
func _submit_serialized_state(serialized_state: PackedByteArray):
	var received_tick: int = serialized_state.decode_u32(0)
	var state_values_size: int = serialized_state.decode_u8(4)
	var serialized_state_values: PackedByteArray = serialized_state.slice(5, 5 + state_values_size)
	var deserialized_state: Dictionary = PropertiesSerializer.deserialize_multiple_properties(serialized_state_values, _props)
	
	_submit_state(deserialized_state, received_tick)

@rpc("authority", "unreliable", "call_remote")
func _submit_state(state: Dictionary, tick: int):
	if tick <= _last_received_tick:
		return
		
	update_last_state_cache(state, tick)
func update_last_state_cache(state: Dictionary, tick: int):
	_last_received_state = state
	_last_received_tick = tick
