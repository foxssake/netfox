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

var _state_property_config: _PropertyConfig = _PropertyConfig.new()
var _input_property_config: _PropertyConfig = _PropertyConfig.new()

var _properties_dirty: bool = false
var _property_cache := PropertyCache.new(root)

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("RollbackSynchronizer")

var _registered_nodes: Array[Node] = []

## Process settings.
##
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	# Deregister all nodes
	for node in _registered_nodes:
		RollbackSimulationServer.deregister_node(node)

	# Clear
	_property_cache.root = root
	_property_cache.clear()

	process_authority()

	# Gather all rollback-aware nodes to simulate during rollbacks
	var nodes := root.find_children("*") as Array[Node]
	nodes.push_front(root)
	nodes = nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))
	nodes.erase(self)

	var input_nodes = []
	for prop in _input_property_config.get_properties():
		var input_node := prop.node
		if not input_nodes.has(input_node):
			input_nodes.append(input_node)

	for node in nodes:
		RollbackSimulationServer.register(node._rollback_tick)
		for input_node in input_nodes:
			RollbackSimulationServer.register_input_for(node, input_node)
		_registered_nodes.append(node)

## Process settings based on authority.
##
## Call this whenever the authority of any of the nodes managed by
## RollbackSynchronizer changes. Make sure to do this at the same time on all
## peers.
func process_authority():
	# Deregister all recorded properties
	for prop in _get_recorded_state_props():
		RollbackHistoryServer.deregister_state(prop.node, prop.property)

	for prop in _get_recorded_input_props():
		RollbackHistoryServer.deregister_input(prop.node, prop.property)

	for prop in _get_owned_input_props():
		RollbackSynchronizationServer.deregister_input(prop.node, prop.property)

	for prop in _get_owned_state_props():
		RollbackSynchronizationServer.deregister_state(prop.node, prop.property)

	# Process authority
	_state_property_config.local_peer_id = multiplayer.get_unique_id()
	_input_property_config.local_peer_id = multiplayer.get_unique_id()

	_state_property_config.set_properties_from_paths(state_properties, _property_cache)
	_input_property_config.set_properties_from_paths(input_properties, _property_cache)

	# Register new recorded properties
	for prop in _get_recorded_state_props():
		RollbackHistoryServer.register_state(prop.node, prop.property)

	for prop in _get_recorded_input_props():
		RollbackHistoryServer.register_input(prop.node, prop.property)

	for prop in _get_owned_input_props():
		RollbackSynchronizationServer.register_input(prop.node, prop.property)

	for prop in _get_owned_state_props():
		RollbackSynchronizationServer.register_state(prop.node, prop.property)

## Add a state property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_state(node: Variant, property: String):
	# TODO: Rewrite
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
	# TODO: Rewrite
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or input_properties.has(property_path):
		return

	input_properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

## Check if input is available for the current tick.
##
## This input is not always current, it may be from multiple ticks ago.
## [br][br]
## Returns true if input is available.
func has_input() -> bool:
	# TODO: Rewrite
	return false

## Get the age of currently available input in ticks.
##
## The available input may be from the current tick, or from multiple ticks ago.
## This number of tick is the input's age.
## [br][br]
## Calling this when [member has_input] is false will yield an error.
func get_input_age() -> int:
	# TODO: Rewrite
	return 0

## Check if the current tick is predicted.
##
## A tick becomes predicted if there's no up-to-date input available. It will be
## simulated and recorded, but will not be broadcast, nor considered
## authoritative.
func is_predicting() -> bool:
	return RollbackSimulationServer.is_predicting_current()

## Ignore a node's prediction for the current rollback tick.
##
## Call this when the input is too old to base predictions on. This call is
## ignored if [member enable_prediction] is false.
func ignore_prediction(node: Node) -> void:
	# TODO: Rewrite
	return

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
	# TODO: Rewrite
	return -1

## Get the tick of the last known state.
## [br][br]
## This is the latest tick where information is available for state. For state
## owners ( usually the host ), this is the current tick. Note that even this
## data may change as new input arrives. For peers that don't own state, this
## will be the tick of the latest state received from the state owner.
func get_last_known_state() -> int:
	# TODO: Rewrite
	# If we own state, this will be updated when recording and broadcasting
	# state, this will be the current tick
	# If we don't own state, this will be updated when state data is received
#	return _history_transmitter.get_latest_state_tick()
	return 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

	process_settings.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

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

func _get_recorded_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_properties()

func _get_owned_state_props() -> Array[PropertyEntry]:
	return _state_property_config.get_owned_properties()

func _get_recorded_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()

func _get_owned_input_props() -> Array[PropertyEntry]:
	return _input_property_config.get_owned_properties()
