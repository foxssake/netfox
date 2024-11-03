extends Node
class_name StateSynchronizer

## Synchronizes state from authority.

@export var root: Node
@export var properties: Array[String]

var _property_cache: PropertyCache
var _property_entries: Array[PropertyEntry]

var _last_received_tick: int = -1
var _last_received_state: Dictionary = {}

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_property_cache = PropertyCache.new(root)
	_property_entries = []

	for property in properties:
		var property_entry = _property_cache.get_entry(property)
		_property_entries.push_back(property_entry)

func _ready():
	process_settings()
	NetworkTime.after_tick.connect(_after_tick)

func _after_tick(_dt, tick):
	if is_multiplayer_authority():
		# Submit snapshot
		var state = PropertySnapshot.extract(_property_entries)
		_submit_state.rpc(state, tick)
	else:
		# Apply last received state
		PropertySnapshot.apply(_last_received_state, _property_cache)

@rpc("authority", "unreliable", "call_remote")
func _submit_state(state: Dictionary, tick: int):
	if tick <= _last_received_tick:
		return
		
	_last_received_state = state
	_last_received_tick = tick
