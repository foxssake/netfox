@tool
extends Node
class_name InputSender

## Stores inputs and sends them to server.
## [br][br]
## [InputSender] can be used alone or with [Simulator].

## The root node for resolving node paths in inputs. Defaults to the parent node.
@export var root: Node = get_parent()

@export_group("Input")
## Properties that define the input for the game simulation.
## [br][br]
## Input properties drive the simulation, which in turn results in updated state
## properties. Input is recorded after every network tick.
@export var input_properties: Array[String]

# Make sure this exists from the get-go, just not in the scene tree
## Decides which peers will receive updates
var visibility_filter := PeerVisibilityFilter.new()

@onready var _logger: NetfoxLogger = NetfoxLogger._for_netfox("InputSender:" + root.name)

var _input_properties := _PropertyPool.new()
var _properties_dirty: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()
	
	if not visibility_filter.get_parent():
		add_child(visibility_filter)
	
	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	process_settings.call_deferred()

## Process settings.
## [br][br]
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	process_authority()
	
	# Register identifiers
	for node in _input_properties.get_subjects():
		NetworkIdentityServer.register_node(node)
	
	# Register visibility filter
	for node in _input_properties.get_subjects():
		NetworkSynchronizationServer.register_visibility_filter(node, visibility_filter)

## Process settings based on authority.
## [br][br]
## Call this whenever the authority of input node changes.
## Make sure to do this at the same time on all peers.
func process_authority():
	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_input_sender_input(node, property)
	
	# Process authority
	_input_properties.set_from_paths(root, input_properties)
	
	# Register new recorded inputs
	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.register_input_sender_input(node, property)

## Add an input property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_input(node: Variant, property: String) -> void:
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or input_properties.has(property_path):
		return

	input_properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()
	elif what == NOTIFICATION_PREDELETE:
		for node in _input_properties.get_subjects():
			NetworkSynchronizationServer.deregister(node)
			NetworkIdentityServer.deregister_node(node)
			NetworkHistoryServer.deregister(node)

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()
	
	# Check if root exists.
	if not root:
		return ["No valid root node found!"]
	
	var result := PackedStringArray()
	
	result.append_array(_NetfoxEditorUtils.gather_properties(root, "_get_input_sender_input_properties",
		func(node, prop):
			add_input(node, prop)
	))
	
	if _input_properties.is_empty() and input_properties.is_empty():
		return ["Input properties are not configured!"]
	
	return result

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()
