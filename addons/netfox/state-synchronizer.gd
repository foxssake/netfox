extends Node
class_name StateSynchronizer

## Synchronizes state from authority.

@export var root: Node
@export var properties: Array[String]

var _property_cache: PropertyCache
var _property_entries: Array[PropertyEntry]
var _properties_dirty: bool = false

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

func add_state(node: Variant, property: String):
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or properties.has(property_path):
		return

	properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

func _connect_signals():
	NetworkTime.after_tick.connect(_after_tick)

func _disconnect_signals():
	NetworkTime.after_tick.disconnect(_after_tick)

func _enter_tree():
	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree():
	_disconnect_signals()

func _after_tick(_dt, tick):
	if is_multiplayer_authority():
		# Submit snapshot
		var state = PropertySnapshot.extract(_property_entries)
		_submit_state.rpc(state, tick)
	else:
		# Apply last received state
		PropertySnapshot.apply(_last_received_state, _property_cache)

func _reprocess_settings():
	if not _properties_dirty:
		return

	_properties_dirty = false
	process_settings()

@rpc("authority", "unreliable", "call_remote")
func _submit_state(state: Dictionary, tick: int):
	if tick <= _last_received_tick:
		return
		
	_last_received_state = state
	_last_received_tick = tick
