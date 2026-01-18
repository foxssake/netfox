@tool
extends Node
class_name StateSynchronizer

## Synchronizes state from authority.
##
## Similar to Godot's [MultiplayerSynchronizer], but is tied to the network tick loop. Works well
## with [TickInterpolator].
## [br][br]
## @tutorial(StateSynchronizer Guide): https://foxssake.github.io/netfox/latest/netfox/nodes/state-synchronizer/

## The root node for resolving node paths in properties.
@export var root: Node

## Properties to record and broadcast.
@export var properties: Array[String]

## Ticks to wait between sending full states.
## [br][br]
## If set to 0, full states will never be sent. If set to 1, only full states
## will be sent. If set higher, full states will be sent regularly, but not
## for every tick.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var full_state_interval: int = 24 # TODO: Don't tie to a network rollback setting?

## Ticks to wait between unreliably acknowledging diff states.
## [br][br]
## This can reduce the amount of properties sent in diff states, due to clients
## more often acknowledging received states. To avoid introducing hickups, these
## are sent unreliably.
## [br][br]
## If set to 0, diff states will never be acknowledged. If set to 1, all diff
## states will be acknowledged. If set higher, ack's will be sent regularly, but
## not for every diff state.
## [br][br]
## If enabled, it's worth to tune this setting until network traffic is actually
## reduced.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var diff_ack_interval: int = 0 # TODO: Don't tie to a network rollback setting?

## Decides which peers will receive updates
var visibility_filter := PeerVisibilityFilter.new()

var _properties_dirty: bool = false
var _registered_properties := [] as Array[PropertyEntry]
var _schema_props := [] as Array[PropertyEntry]

var _is_initialized: bool = false

static var _logger := NetfoxLogger._for_netfox("StateSynchronizer")

## Process settings.
## [br][br]
## Call this after any change to configuration.
func process_settings() -> void:
	# Remove old configuration
	for property in _registered_properties:
		RollbackHistoryServer.deregister_sync_state(property.node, property.property)
		RollbackSynchronizationServer.deregister_sync_state(property.node, property.property)

	# Register new configuration
	_registered_properties.clear()
	for property_spec in properties:
		var property := PropertyEntry.parse(root, property_spec)
		_registered_properties.append(property)
		RollbackHistoryServer.register_sync_state(property.node, property.property)
		RollbackSynchronizationServer.register_sync_state(property.node, property.property)
		# TODO: Somehow deregister on destroy
		NetworkIdentityServer.register_node(property.node)

	_is_initialized = true

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

## Set the schema for transmitting properties over the network.
## [br][br]
## The [param schema] must be a dictionary, with the keys being property path
## strings, and the values are the associated [NetworkSchemaSerializer] objects.
## Properties are interpreted relative to the [member root] node. Properties not
## specified in the schema will use a generic fallback serializer. By using the
## right serializer for the right property, bandwidth usage can be lowered.
## [br][br]
## See [NetworkSchemas] for many common serializers.
## [br][br]
## Example:
## [codeblock]
##    state_synchronizer.set_schema({
##        ":transform": NetworkSchemas.transform3f32(),
##        ":velocity": NetworkSchemas.vec3f32()
##    })
## [/codeblock]
func set_schema(schema: Dictionary) -> void:
	# Remove previous schema
	for entry in _schema_props:
		RollbackSynchronizationServer.deregister_schema(entry.node, entry.property)
	_schema_props.clear()

	# Register new schema
	for prop in schema:
		var prop_entry := PropertyEntry.parse(root, prop)
		var serializer := schema[prop] as NetworkSchemaSerializer
		RollbackSynchronizationServer.register_schema(prop_entry.node, prop_entry.property, serializer)
		_schema_props.append(prop_entry)

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

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()
	if not visibility_filter.get_parent():
		add_child(visibility_filter)

	process_settings.call_deferred()

func _ready():
	# Reprocess authority
	# Important if nodes are pre-placed in the scene - node starts as owned by
	# us ( offline peer is 1 ), but once we connect, we no longer own the node
	multiplayer.connected_to_server.connect(process_settings)

func _reprocess_settings() -> void:
	if not _properties_dirty:
		return

	_properties_dirty = false
	process_settings()
