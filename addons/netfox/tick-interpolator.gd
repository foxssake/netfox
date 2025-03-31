@tool
extends Node
class_name TickInterpolator

## Interpolates between network ticks for smooth motion.
## [br][br]
## @tutorial(TickInterpolator Guide): https://foxssake.github.io/netfox/latest/netfox/nodes/tick-interpolator/

## The root node for resolving node paths in properties.
@export var root: Node

## Toggles interpolation.
@export var enabled: bool = true

## Properties to interpolate.
@export var properties: Array[String]

## If enabled, takes a snapshot immediately upon instantiation, instead of
## waiting for the first network tick. Useful for objects that start moving
## instantly, like projectiles.
@export var record_first_state: bool = true

## Toggle automatic state recording. When enabled, the node will take a new
## snapshot on every network tick. When disabled, call [member push_state]
## whenever properties are updated.
@export var enable_recording: bool = true

var _state_from: _PropertySnapshot
var _state_to: _PropertySnapshot
var _property_entries: Array[PropertyEntry] = []
var _properties_dirty: bool = false
var _interpolators: Dictionary = {}
var _is_teleporting: bool = false

var _property_cache: PropertyCache

## Process settings.
## [br][br]
## Call this after any change to configuration.
func process_settings():
	_property_cache = PropertyCache.new(root)
	_property_entries.clear()
	_interpolators.clear()

	_state_from = _PropertySnapshot.new()
	_state_to = _PropertySnapshot.new()

	for property in properties:
		var property_entry = _property_cache.get_entry(property)
		_property_entries.push_back(property_entry)
		_interpolators[property] = Interpolators.find_for(property_entry.get_value())

## Add a property to interpolate.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already interpolated, this method does nothing.
func add_property(node: Variant, property: String):
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or properties.has(property_path):
		return

	properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

## Check if interpolation can be done.
## [br][br]
## Even if it's enabled, no interpolation will be done if there are no
## properties to interpolate.
func can_interpolate() -> bool:
	return enabled and not properties.is_empty() and not _is_teleporting

## Record current state for interpolation.
## [br][br]
## Note that this will rotate the states, so the previous target becomes the new
## starting point for the interpolation. This is automatically called if
## [code]enable_recording[/code] is true.
func push_state() -> void:
	_state_from = _state_to
	_state_to = _PropertySnapshot.extract(_property_entries)

## Record current state and transition without interpolation.
func teleport() -> void:
	if _is_teleporting:
		return

	_state_from = _PropertySnapshot.extract(_property_entries)
	_state_to = _state_from
	_is_teleporting = true

func _notification(what) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()

	# Explore interpolated properties
	if not root:
		return ["No valid root node found!"]

	return _NetfoxEditorUtils.gather_properties(root, "_get_interpolated_properties",
		func(node, prop):
			add_property(node, prop)
	)

func _connect_signals() -> void:
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _disconnect_signals() -> void:
	NetworkTime.before_tick_loop.disconnect(_before_tick_loop)
	NetworkTime.after_tick_loop.disconnect(_after_tick_loop)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	process_settings.call_deferred()
	_connect_signals.call_deferred()

	# Wait a frame for any initial setup before recording first state
	if record_first_state:
		await get_tree().process_frame
		teleport()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_signals()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_interpolate(_state_from, _state_to, NetworkTime.tick_factor)

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()

func _before_tick_loop() -> void:
	_is_teleporting = false
	_state_to.apply(_property_cache)

func _after_tick_loop() -> void:
	if enable_recording and not _is_teleporting:
		push_state()
		_state_from.apply(_property_cache)

func _interpolate(from: _PropertySnapshot, to: _PropertySnapshot, f: float) -> void:
	if not can_interpolate():
		return

	for property in from.properties():
		if not to.has(property): continue

		var property_entry := _property_cache.get_entry(property)
		var a := from.get_value(property)
		var b := to.get_value(property)
		var interpolate = _interpolators[property] as Callable

		property_entry.set_value(interpolate.call(a, b, f))
