@tool
extends Node
class_name RollbackSynchronizer

## Similar to [MultiplayerSynchronizer], this class is responsible for
## synchronizing data between players, but with support for rollback.
## [br][br]
## @tutorial(RollbackSynchronizer Guide): https://foxssake.github.io/netfox/latest/netfox/nodes/rollback-synchronizer/

## The root node for resolving node paths in properties. Defaults to the parent
## node.
@export var root: Node = get_parent()

## Toggle prediction.
## [br][br]
## Enabling this will run [code]_rollback_tick[/code] on nodes under
## [member root] even if there's no current input available for the tick.
@export var enable_prediction: bool = false

@export_group("State")
## Properties that define the game state.
## [br][br]
## State properties are recorded for each tick and restored during rollback.
## State is restored before every rollback tick, and recorded after simulating
## the tick.
@export var state_properties: Array[String]

## Ticks to wait between sending full states.
## [br][br]
## If set to 0, full states will never be sent. If set to 1, only full states
## will be sent. If set higher, full states will be sent regularly, but not
## for every tick.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var full_state_interval: int = 24

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
var diff_ack_interval: int = 0

@export_group("Inputs")
## Properties that define the input for the game simulation.
## [br][br]
## Input properties drive the simulation, which in turn results in updated state
## properties. Input is recorded after every network tick.
@export var input_properties: Array[String]

## This will broadcast input to all peers, turning this off will limit to
## sending it to the server only. Turning this off is recommended to save
## bandwidth and reduce cheating risks.
@export var enable_input_broadcast: bool = true

# Make sure this exists from the get-go, just not in the scene tree
## Decides which peers will receive updates
var visibility_filter := PeerVisibilityFilter.new()

var _state_properties := _PropertyPool.new()
var _input_properties := _PropertyPool.new()
var _sim_nodes := [] as Array[Node]
var _schema_nodes := _Set.new()

var _properties_dirty: bool = false
var _property_cache := PropertyCache.new(root)

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("RollbackSynchronizer")

## Process settings.
## [br][br]
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	# Deregister simulated, state and input nodes
	for node in _sim_nodes + _state_properties.get_subjects() + _input_properties.get_subjects():
		RollbackSimulationServer.deregister_node(node)
	_sim_nodes.clear()

	# Clear
	_property_cache.root = root
	_property_cache.clear()

	process_authority()

	# Gather all rollback-aware nodes to simulate during rollbacks
	var nodes := root.find_children("*") as Array[Node]
	nodes.push_front(root)
	nodes = nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))
	nodes.erase(self)

	# Register simulation callbacks
	for node in nodes:
		RollbackSimulationServer.register(node._rollback_tick)
		_sim_nodes.append(node)
		
	# Both simulated and state nodes depend on all inputs
	# TODO(#564): Write tests for setups where a node is synchronized but not simulated
	for node in nodes + _state_properties.get_subjects():
		for input_node in _input_properties.get_subjects():
			RollbackSimulationServer.register_input_for(node, input_node)

	# Register identifiers
	for node in _state_properties.get_subjects() + _input_properties.get_subjects():
		NetworkIdentityServer.register_node(node)

	# Register visibility filter
	for node in _state_properties.get_subjects():
		NetworkSynchronizationServer.register_visibility_filter(node, visibility_filter)

## Process settings based on authority.
## [br][br]
## Call this whenever the authority of any of the nodes managed by
## RollbackSynchronizer changes. Make sure to do this at the same time on all
## peers.
func process_authority():
	# Deregister all recorded properties
	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_state(node, property)
			NetworkSynchronizationServer.deregister_state(node, property)

	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_input(node, property)
			NetworkSynchronizationServer.deregister_input(node, property)

	# Process authority
	_state_properties.set_from_paths(root, state_properties)
	_input_properties.set_from_paths(root, input_properties)

	# Register new recorded properties
	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.register_state(node, property)
			NetworkSynchronizationServer.register_state(node, property)

	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.register_input(node, property)
			NetworkSynchronizationServer.register_input(node, property)

## Add a state property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_state(node: Variant, property: String):
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or state_properties.has(property_path):
		return

	state_properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

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

## Set the schema for transmitting properties over the network.
## [br][br]
## The [param schema] must be a dictionary, with the keys being property path
## strings, and the values are the associated [NetworkSchemaSerializer] objects.
## Properties are interpreted relative to the [member root] node. The schema can
## contain both state and input properties. Properties not specified in the
## schema will use a generic fallback serializer. By using the right serializer
## for the right property, bandwidth usage can be lowered.
## [br][br]
## See [NetworkSchemas] for many common serializers.
## [br][br]
## Example:
## [codeblock]
##    rollback_synchronizer.set_schema({
##        ":transform": NetworkSchemas.transform3f32(),
##        ":velocity": NetworkSchemas.vec3f32(),
##        "Input:movement": NetworkSchemas.vec3f32()
##    })
## [/codeblock]
func set_schema(schema: Dictionary) -> void:
	# Remove previous schema
	for node in _schema_nodes:
		NetworkSynchronizationServer.deregister_schema_for(node)
	_schema_nodes.clear()

	# Register new schema
	for prop in schema:
		var prop_entry := PropertyEntry.parse(root, prop)
		var serializer := schema[prop] as NetworkSchemaSerializer
		NetworkSynchronizationServer.register_schema(prop_entry.node, prop_entry.property, serializer)
		_schema_nodes.add(prop_entry.node)

## Check if input is available for the current tick.
## [br][br]
## This input is not always current, it may be from multiple ticks ago.
## [br][br]
## Returns true if input is available.
func has_input() -> bool:
	return get_input_age() >= 0

## Get the age of currently available input in ticks.
## [br][br]
## The available input may be from the current tick, or from multiple ticks ago.
## This number of tick is the input's age.
func get_input_age() -> int:
	return NetworkHistoryServer.get_input_age_for(_input_properties.get_subjects(), NetworkRollback.tick)

## Check if the current tick is predicted.
## [br][br]
## A tick becomes predicted if there's no up-to-date input available. It will be
## simulated and recorded, but will not be broadcast, nor considered
## authoritative.
func is_predicting() -> bool:
	if RollbackSimulationServer.get_simulated_object() != null:
		# An object is being simulated, check if it's predicted
		return RollbackSimulationServer.is_predicting_current()
	else:
		# We're outside of simulation, predicting if we don't have current input
		return get_input_age() != 0

## Ignore a node's prediction for the current rollback tick.
## [br][br]
## Call this when the input is too old to base predictions on. This call is
## ignored if [member enable_prediction] is false.
func ignore_prediction(node: Node) -> void:
	# Not needed, netfox records properties as non-auth if predicting
	# Once the data is received from the owner, it won't be overwritten by
	# predictions.
	#
	# This method may see some use again, otherwise it will be deprecated.
	pass

## Get the tick of the last known input.
## [br][br]
## This is the latest tick where input information is available. If there's
## locally owned input for this instance ( e.g. running as client ), this value
## will be the current tick. Otherwise, this will be the latest tick received
## from the input owner.
## [br][br]
## If [member enable_input_broadcast] is false, there may be no input available
## for peers who own neither state nor input.
## [br][br]
## Returns -1 if there's no known input.
func get_last_known_input() -> int:
	return NetworkHistoryServer.get_input_age_for(_input_properties.get_subjects(), NetworkTime.tick)

## Get the tick of the last known state.
## [br][br]
## This is the latest tick where information is available for state. For state
## owners ( usually the host ), this is the current tick. Note that even this
## data may change as new input arrives. For peers that don't own state, this
## will be the tick of the latest state received from the state owner.
func get_last_known_state() -> int:
	return NetworkHistoryServer.get_state_age_for(_state_properties.get_subjects(), NetworkTime.tick)

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

	process_settings.call_deferred()
	multiplayer.connected_to_server.connect(process_settings)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()
	elif what == NOTIFICATION_PREDELETE:
		for node in _sim_nodes + _state_properties.get_subjects() + _input_properties.get_subjects():
			RollbackSimulationServer.deregister_node(node)
			NetworkSynchronizationServer.deregister(node)
			NetworkIdentityServer.deregister_node(node)
			NetworkHistoryServer.deregister(node)

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()

	# Explore state and input properties
	if not root:
		return ["No valid root node found!"]

	var result := PackedStringArray()
	result.append_array(_NetfoxEditorUtils.gather_properties(root, "_get_rollback_state_properties",
		func(node, prop):
			add_state(node, prop)
	))

	result.append_array(_NetfoxEditorUtils.gather_properties(root, "_get_rollback_input_properties",
		func(node, prop):
			add_input(node, prop)
	))

	return result

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

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()
