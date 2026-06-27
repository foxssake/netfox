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

var _properties_dirty: bool = false
var _properties := _PropertyPool.new()

@onready var _logger := NetfoxLogger._for_netfox("TickInterpolator:%s" % [root.name])

## Process settings.
## [br][br]
## Call this after any change to configuration.
func process_settings():
	if not root:
		root = get_parent()

	# Deregister old settings
	for subject in _properties.get_subjects():
		InterpolationServer.deregister(subject)

	# Register new settings
	_properties.set_from_paths(root, properties)
	for subject in _properties.get_subjects():
		for property in _properties.get_properties_of(subject):
			_logger.debug("Registered property: %s:%s", [subject, property])
			InterpolationServer.register(subject, property)

		InterpolationServer.set_enabled(subject, enabled)
		InterpolationServer.set_recording(subject, enable_recording)

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
	for subject in _properties.get_subjects():
		if not InterpolationServer.can_interpolate(subject):
			return false
	return true

## Record current state for interpolation.
## [br][br]
## Note that this will rotate the states, so the previous target becomes the new
## starting point for the interpolation. This is automatically called if
## [code]enable_recording[/code] is true.
func push_state() -> void:
	for subject in _properties.get_subjects():
		InterpolationServer.push_state(subject)

## Record current state and transition without interpolation.
func teleport() -> void:
	for subject in _properties.get_subjects():
		InterpolationServer.teleport(subject)

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

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	process_settings.call_deferred()

	# Wait a frame for any initial setup before recording first state
	if record_first_state:
		await get_tree().process_frame
		teleport()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	for subject in _properties.get_subjects():
		InterpolationServer.deregister(subject)

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()
