@tool
extends Node
class_name PredictiveSynchronizer

## Similar to [RollbackSynchronizer], this class manages local variables in a 
## rollback context for predictive simulation without networking.
##
## This is a simplified version that focuses on local state management.
## [br][br]
## Like [RollbackSynchronizer], it automatically discovers nodes 
## with a [code]_rollback_tick(delta: float, tick: int)[/code]
## method and calls them during the prediction phase.

## The root node for resolving node paths in properties. Defaults to the parent
## node.
@export var root: Node = get_parent()

@export_group("State")
## Properties that define the game state.
## [br][br]
## State properties are recorded for each tick and restored during rollback.
## State is restored before every rollback tick, and recorded after simulating
## the tick.
@export var state_properties: Array[String]

var _state_properties := _PropertyPool.new()
var _sim_nodes: Array[Node] = []

var _properties_dirty: bool = false

## Process settings.
##
## Call this after any change to configuration.
func process_settings() -> void:
	# Deregister all nodes we've registered previously
	for subject in _state_properties.get_subjects():
		NetworkHistoryServer.deregister(subject)

	for node in _sim_nodes:
		RollbackSimulationServer.deregister_node(node)

	# Gather all prediction-aware nodes to call during prediction ticks
	_sim_nodes = root.find_children("*")
	_sim_nodes.push_front(root)
	_sim_nodes = _sim_nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))
	_sim_nodes.erase(self)

	# Keep history of state properties
	_state_properties.set_from_paths(root, state_properties)
	for subject in _state_properties.get_subjects():
		for property in _state_properties.get_properties_of(subject):
			NetworkHistoryServer.register_rollback_state(subject, property)

	# Simulated notes to participate in rollback
	for node in _sim_nodes:
		RollbackSimulationServer.register(NetworkRollback._get_rollback_method(node))

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

	process_settings.call_deferred()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	process_settings.call_deferred()

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()

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

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()
	if what == NOTIFICATION_PREDELETE:
		for node in _sim_nodes:
			RollbackSimulationServer.deregister_node(node)
		for subject in _state_properties.get_subjects():
			NetworkHistoryServer.deregister(subject)

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()

	# Explore state properties
	if not root:
		return ["No valid root node found!"]

	var result := PackedStringArray()
	result.append_array(_NetfoxEditorUtils.gather_properties(root, "_get_rollback_state_properties",
		func(node, prop):
			add_state(node, prop)
	))

	return result
