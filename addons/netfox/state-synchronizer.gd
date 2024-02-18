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
		var state = PropertySnapshot.extract(_props)
		rpc("_submit_state", state, tick)
	else:
		# Apply last received state
		PropertySnapshot.apply(_last_received_state, _property_cache)

@rpc("authority", "unreliable", "call_remote")
func _submit_state(state: Dictionary, tick: int):
	if tick <= _last_received_tick:
		return
		
	_last_received_state = state
	_last_received_tick = tick
