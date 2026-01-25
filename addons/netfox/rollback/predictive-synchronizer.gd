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

var _state_property_config: _PropertyConfig = _PropertyConfig.new()
var _property_cache := PropertyCache.new(root)
var _freshness_store := RollbackFreshnessStore.new()

var _states := _PropertyHistoryBuffer.new()
var _nodes: Array[Node] = []
var _skipset: _Set = _Set.new()

var _properties_dirty: bool = false

# Composition
var _history_recorder: _RollbackHistoryRecorder

## Process settings.
##
## Call this after any change to configuration.
func process_settings() -> void:
	_property_cache.root = root
	_property_cache.clear()
	_freshness_store.clear()

	_nodes.clear()
	_states.clear()

	# Gather all prediction-aware nodes to call during prediction ticks
	_nodes = root.find_children("*")
	_nodes.push_front(root)
	_nodes = _nodes.filter(func(n): return NetworkRollback.is_rollback_aware(n))
	_nodes.erase(self)

	_state_property_config.set_properties_from_paths(state_properties, _property_cache)

	if _history_recorder == null:
		_history_recorder = _RollbackHistoryRecorder.new()
	
	var _inputs := _PropertyHistoryBuffer.new()
	var _input_property_config := _PropertyConfig.new()
	_history_recorder.configure(_states, _inputs, _state_property_config, _input_property_config, _property_cache, _skipset)

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

	process_settings.call_deferred()

func _connect_signals() -> void:
	NetworkTime.before_tick.connect(_before_tick)
	NetworkTime.after_tick.connect(_after_tick)
	
	NetworkRollback.on_prepare_tick.connect(_on_prepare_tick)
	NetworkRollback.on_process_tick.connect(_run_prediction_tick)
	NetworkRollback.on_record_tick.connect(_on_record_tick)

func _disconnect_signals() -> void:
	NetworkTime.before_tick.disconnect(_before_tick)
	NetworkTime.after_tick.disconnect(_after_tick)
	
	NetworkRollback.on_prepare_tick.disconnect(_on_prepare_tick)
	NetworkRollback.on_process_tick.disconnect(_run_prediction_tick)
	NetworkRollback.on_record_tick.disconnect(_on_record_tick)

func _before_tick(_dt: float, tick: int) -> void:
	_history_recorder.apply_state(tick)

func _after_tick(_dt: float, tick: int) -> void:
	_history_recorder.trim_history()
	_freshness_store.trim()

func _on_prepare_tick(tick: int) -> void:
	_history_recorder.apply_tick(tick)

func _on_record_tick(tick: int) -> void:
	_history_recorder.record_state(tick)

func _run_prediction_tick(tick: int) -> void:
	for node in _nodes:
		var is_fresh := _freshness_store.is_fresh(node, tick)
		NetworkRollback.process_rollback(node, NetworkTime.ticktime, tick, is_fresh)
		_freshness_store.notify_processed(node, tick)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_signals()

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
