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
@export var enable_prediction: bool = false:
	set(v):
		if v != enable_prediction:
			_set_prediction_enabled(v)
			enable_prediction = v

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
## @deprecated: This can now be configured in the project settings.
@export_range(0, 128, 1, "or_greater")
var full_state_interval: int = 24

## @deprecated: This is no longer used.
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
## @deprecated: This can now be configured in the project settings.
@export var enable_input_broadcast: bool = true

# Make sure this exists from the get-go, just not in the scene tree
## Decides which peers will receive updates
var visibility_filter := PeerVisibilityFilter.new()

var _state_properties := _PropertyPool.new()
var _input_properties := _PropertyPool.new()
var _sim_nodes := [] as Array[Node]
var _liveness_nodes := [] as Array[Node]
var _schema_nodes := _Set.new()

var _properties_dirty: bool = false

static var _managed_roots := {} # root node to RollbackSynchronizer

@onready var _logger: NetfoxLogger = NetfoxLogger._for_netfox("RollbackSynchronizer:" + root.name)

## Process settings.
## [br][br]
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	# Deregister simulated, state and input nodes
	for node in _sim_nodes + _state_properties.get_subjects() + _input_properties.get_subjects():
		RollbackSimulationServer.deregister_node(node)
	_sim_nodes.clear()

	process_authority()

	# Register nodes for simulation and liveness
	var managed_nodes := [root] + _collect_managed_nodes(root)
	_logger.debug("Filtering managed nodes: %s", [managed_nodes])
	for node in managed_nodes:
		if NetworkRollback.is_rollback_aware(node):
			RollbackSimulationServer.register(NetworkRollback._get_rollback_method(node))
			RollbackSimulationServer.set_prediction_enabled_for(node, enable_prediction)
			_sim_nodes.append(node)

		if NetworkRollback.is_rollback_liveness_aware(node) and not RollbackLivenessServer.is_registered(node):
			var spawn_callback := NetworkRollback._get_rollback_spawn_method(node)
			var despawn_callback := NetworkRollback._get_rollback_despawn_method(node)
			var free_callback := NetworkRollback._get_rollback_destroy_method(node)

			RollbackLivenessServer.register(node, spawn_callback, despawn_callback, free_callback)
			_liveness_nodes.append(node)

	# Both simulated and state nodes depend on all inputs
	# TODO(#564): Write tests for setups where a node is synchronized but not simulated
	for node in _sim_nodes + _state_properties.get_subjects():
		for input_node in _input_properties.get_subjects():
			RollbackSimulationServer.register_rollback_input_for(node, input_node)

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
			NetworkHistoryServer.deregister_rollback_state(node, property)
			NetworkSynchronizationServer.deregister_rollback_state(node, property)

	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_rollback_input(node, property)
			NetworkSynchronizationServer.deregister_rollback_input(node, property)

	# Process authority
	_state_properties.set_from_paths(root, state_properties)
	_input_properties.set_from_paths(root, input_properties)

	# Register new recorded properties
	for node in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(node):
			NetworkHistoryServer.register_rollback_state(node, property)
			NetworkSynchronizationServer.register_rollback_state(node, property)

	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.register_rollback_input(node, property)
			NetworkSynchronizationServer.register_rollback_input(node, property)

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
	clear_schema()

	# Register new schema
	merge_schema(schema)

## Add serializers from [param schema].
## [br][br]
## See [method set_schema] for specifying [param schema]. As opposed to [method
## set_schema], this method updates the schema, instead of overriding it. If
## a property had a serializer specified previously, this will replace it.
func merge_schema(schema: Dictionary) -> void:
	for prop in schema:
		var prop_entry := PropertyEntry.parse(root, prop)
		var serializer := schema[prop] as NetworkSchemaSerializer
		NetworkSynchronizationServer.register_schema(prop_entry.node, prop_entry.property, serializer)
		_schema_nodes.add(prop_entry.node)

## Clear any serializers specified earlier.
## [br][br]
## See [method set_schema].
func clear_schema() -> void:
	for node in _schema_nodes:
		NetworkSynchronizationServer.deregister_schema_for(node)
	_schema_nodes.clear()

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

	# NOTE: Turns out this is useful - even if mispredictions are not recorded,
	# we might not want to display them
	NetworkHistoryServer.ignore(node)

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
	return NetworkHistoryServer.get_latest_input_for(_input_properties.get_subjects(), NetworkTime.tick)

## Get the tick of the last known state.
## [br][br]
## This is the latest tick where information is available for state. For state
## owners ( usually the host ), this is the current tick. Note that even this
## data may change as new input arrives. For peers that don't own state, this
## will be the tick of the latest state received from the state owner.
func get_last_known_state() -> int:
	return NetworkHistoryServer.get_state_age_for(_state_properties.get_subjects(), NetworkTime.tick)

## Mark the spawn tick for all nodes managed by this synchronizer.
## [br][br]
## When rewinding to a tick earlier than the spawn tick, every managed node will
## be deactivated.
func spawn(p_tick: int = NetworkRollback.tick) -> void:
	for node in _liveness_nodes:
		RollbackLivenessServer.spawn(node, p_tick)

## Mark the despawn tick for all nodes managed by this synchronizer.
## [br][br]
## When rewinding to a tick later than the despawn tick, every managed node will
## be deactivated.
func despawn(p_tick: int = NetworkRollback.tick) -> void:
	for node in _liveness_nodes:
		RollbackLivenessServer.despawn(node, p_tick)

## Return true if nodes managed by this synchronizer are alive.
## [br][br]
## Note that this method assumes that all node liveness is managed by the
## synchronizer. If some node livenesses are handled separately, this method
## may return the wrong liveness. In that case, use
## [method _RollbackLivenessServer.is_alive] and check for individual
## nodes.
func is_alive(p_tick: int = NetworkRollback.tick) -> bool:
	if _liveness_nodes.is_empty():
		return true
	return RollbackLivenessServer.is_alive(_liveness_nodes.front(), p_tick)

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

		for node in _liveness_nodes:
			RollbackLivenessServer.deregister(node)

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

	_managed_roots[root] = self

	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()

	if not visibility_filter.get_parent():
		add_child(visibility_filter)

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	process_settings.call_deferred()

func _exit_tree() -> void:
	_managed_roots.erase(root)

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()

func _set_prediction_enabled(enabled: bool) -> void:
	for node in _sim_nodes:
		RollbackSimulationServer.set_prediction_enabled_for(node, enabled)

# Find managed nodes recursively from given root, ignoring branches managed by
# a different RollbackSynchronizer
func _collect_managed_nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in root.get_children():
		if _is_foreign_rollback_root(child):
			continue
		result.append(child)
		result.append_array(_collect_managed_nodes(child))
	return result

# Returns true if the node is the root of a different RollbackSynchronizer
func _is_foreign_rollback_root(node: Node) -> bool:
	if not _managed_roots.has(node):
		# No RBS treats node as root
		return false

	if _managed_roots[node] == self:
		# Node is our own root
		return false

	# Node is foreign root
	return true
