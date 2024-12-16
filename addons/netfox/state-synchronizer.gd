@tool
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

func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

func _get_configuration_warnings():
	var result = []

	if not root:
		root = get_parent()

	# Explore state properties
	if not root:
		return ["No valid root node found!"]

	var nodes: Array[Node] = root.find_children("*")
	nodes.push_back(root)
	for node in nodes:
		if not node.has_method(&"_get_synchronized_state_properties"):
			continue
		
		if node.get_script() != null and not node.get_script().is_tool():
			result.push_back("Node \"%s\" (\"%s\") has a non-@tool script!" % [root.get_path_to(node), node.name])
			continue

		var props = node._get_synchronized_state_properties()
		for prop in props:
			add_state(node, prop)

	return result

func _connect_signals():
	NetworkTime.after_tick.connect(_after_tick)

func _disconnect_signals():
	NetworkTime.after_tick.disconnect(_after_tick)

func _enter_tree():
	if Engine.is_editor_hint():
		return

	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree():
	if Engine.is_editor_hint():
		return

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
