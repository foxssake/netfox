@tool
extends Node
class_name StateSynchronizer

## Synchronizes state from authority.
##
## Similar to Godot's [MultiplayerSynchronizer], but is tied to the network tick loop. Works well
## with [TickInterpolator].
## [br][br]
## @tutorial(StateSynchronizer Guide): https://foxssake.github.io/netfox/netfox/nodes/state-synchronizer/

## The root node for resolving node paths in properties.
@export var root: Node

## Properties to record and broadcast.
@export var properties: Array[String]

var _property_cache: PropertyCache
var _property_entries: Array[PropertyEntry]
var _properties_dirty: bool = false

var _last_received_tick: int = -1
var _last_received_state: _PropertySnapshot = _PropertySnapshot.new()

## Process settings.
## [br][br]
## Call this after any change to configuration.
func process_settings() -> void:
	_property_cache = PropertyCache.new(root)
	_property_entries = []

	for property in properties:
		var property_entry := _property_cache.get_entry(property)
		_property_entries.push_back(property_entry)

## Add a state property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_state(node: Variant, property: String) -> void:
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or properties.has(property_path):
		return

	properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

func _notification(what) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()

	# Explore state properties
	if not root:
		return ["No valid root node found!"]

	return _NetfoxEditorUtils.gather_properties(root, "_get_synchronized_state_properties",
		func(node, prop):
			add_state(node, prop)
	)

func _connect_signals() -> void:
	NetworkTime.after_tick.connect(_after_tick)

func _disconnect_signals() -> void:
	NetworkTime.after_tick.disconnect(_after_tick)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_signals()

func _after_tick(_dt: float, tick: int) -> void:
	if is_multiplayer_authority():
		# Submit snapshot
		var state := _PropertySnapshot.extract(_property_entries)
		_submit_state.rpc(state.as_dictionary(), tick)
	else:
		# Apply last received state
		_last_received_state.apply(_property_cache)

func _reprocess_settings() -> void:
	if not _properties_dirty:
		return

	_properties_dirty = false
	process_settings()

@rpc("authority", "unreliable", "call_remote")
func _submit_state(state: Dictionary, tick: int) -> void:
	if tick <= _last_received_tick:
		return

	_last_received_state = _PropertySnapshot.from_dictionary(state)
	_last_received_tick = tick
