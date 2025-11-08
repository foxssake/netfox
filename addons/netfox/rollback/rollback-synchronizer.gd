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
var _nodes: Array[Node] = []

var _simset: _Set = _Set.new()
var _skipset: _Set = _Set.new()

var _properties_dirty: bool = false

var _property_cache := PropertyCache.new(root)
var _freshness_store := RollbackFreshnessStore.new()

var _states := _PropertyHistoryBuffer.new()
var _inputs := _PropertyHistoryBuffer.new()
var _last_simulated_tick: int

var _has_input: bool
var _input_tick: int
var _is_predicted_tick: bool

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("RollbackSynchronizer")

# Composition
var _history_transmitter: _RollbackHistoryTransmitter
var _history_recorder: _RollbackHistoryRecorder

## Process settings.
##
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	_property_cache.root = root
	_property_cache.clear()
	_freshness_store.clear()

	_nodes.clear()

	_states.clear()
	_inputs.clear()
	process_authority()

	# Gather all rollback-aware nodes to simulate during rollbacks
	_nodes = root.find_children("*")
	_nodes.push_front(root)
	_nodes = _nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))
	_nodes.erase(self)

	_history_transmitter.sync_settings(root, enable_input_broadcast, full_state_interval, diff_ack_interval)
	_history_transmitter.configure(_states, _inputs, _state_property_config, _input_property_config, visibility_filter, _property_cache, _skipset)
	_history_recorder.configure(_states, _inputs, _state_property_config, _input_property_config, _property_cache, _skipset)

## Process settings based on authority.
##
## Call this whenever the authority of any of the nodes managed by
## RollbackSynchronizer changes. Make sure to do this at the same time on all
## peers.
func process_authority():
	_state_property_config.local_peer_id = multiplayer.get_unique_id()
	_input_property_config.local_peer_id = multiplayer.get_unique_id()

	_state_property_config.set_properties_from_paths(state_properties, _property_cache)
	_input_property_config.set_properties_from_paths(input_properties, _property_cache)

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

## Check if input is available for the current tick.
##
## This input is not always current, it may be from multiple ticks ago.
## [br][br]
## Returns true if input is available.
func has_input() -> bool:
	return _has_input

## Get the age of currently available input in ticks.
##
## The available input may be from the current tick, or from multiple ticks ago.
## This number of tick is the input's age.
## [br][br]
## Calling this when [member has_input] is false will yield an error.
func get_input_age() -> int:
	if has_input():
		return NetworkRollback.tick - _input_tick
	else:
		_logger.error("Trying to check input age without having input!")
		return -1

## Check if the current tick is predicted.
##
## A tick becomes predicted if there's no up-to-date input available. It will be
## simulated and recorded, but will not be broadcast, nor considered
## authoritative.
func is_predicting() -> bool:
	return _is_predicted_tick

## Ignore a node's prediction for the current rollback tick.
##
## Call this when the input is too old to base predictions on. This call is
## ignored if [member enable_prediction] is false.
func ignore_prediction(node: Node) -> void:
	if enable_prediction:
		_skipset.add(node)

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
	# If we own input, it is updated regularly, this will be the current tick
	# If we don't own input, _inputs is only updated when input data is received
	if not _inputs.is_empty():
		return _inputs.keys().max()
	return -1

## Get the tick of the last known state.
## [br][br]
## This is the latest tick where information is available for state. For state
## owners ( usually the host ), this is the current tick. Note that even this
## data may change as new input arrives. For peers that don't own state, this
## will be the tick of the latest state received from the state owner.
func get_last_known_state() -> int:
	# If we own state, this will be updated when recording and broadcasting
	# state, this will be the current tick
	# If we don't own state, this will be updated when state data is received
	return _history_transmitter.get_latest_state_tick()

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
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkRollback.on_record_tick.connect(_on_record_tick)

	NetworkRollback.before_loop.connect(_before_rollback_loop)
	NetworkRollback.after_loop.connect(_after_rollback_loop)

func _disconnect_signals() -> void:
	NetworkTime.before_tick.disconnect(_before_tick)
	NetworkTime.after_tick.disconnect(_after_tick)

	NetworkRollback.on_prepare_tick.disconnect(_on_prepare_tick)
	NetworkRollback.on_process_tick.disconnect(_process_tick)
	NetworkRollback.on_record_tick.disconnect(_on_record_tick)

	NetworkRollback.before_loop.disconnect(_before_rollback_loop)
	NetworkRollback.after_loop.disconnect(_after_rollback_loop)

func _before_tick(_dt: float, tick: int) -> void:
	_history_recorder.apply_state(tick)

func _after_tick(_dt: float, tick: int) -> void:
	_history_recorder.record_input(tick)
	_history_transmitter.transmit_input(tick)
	_history_recorder.trim_history()
	_freshness_store.trim()

func _before_rollback_loop() -> void:
	_notify_resim()

func _on_prepare_tick(tick: int) -> void:
	_history_recorder.apply_tick(tick)
	_prepare_tick_process(tick)

func _process_tick(tick: int) -> void:
	_run_rollback_tick(tick)
	_push_simset_metrics()

func _on_record_tick(tick: int) -> void:
	_history_recorder.record_state(tick)
	_history_transmitter.transmit_state(tick)

func _after_rollback_loop() -> void:
	_history_recorder.apply_display_state()
	_history_transmitter.conclude_tick_loop()

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

	if _history_transmitter == null:
		_history_transmitter = _RollbackHistoryTransmitter.new()
		add_child(_history_transmitter, true)
		_history_transmitter.set_multiplayer_authority(get_multiplayer_authority())

	if _history_recorder == null:
		_history_recorder = _RollbackHistoryRecorder.new()

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_signals()

func _notify_resim() -> void:
	if _get_owned_input_props().is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_resimulation_start(_history_transmitter.get_earliest_input_tick())
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_resimulation_start(_history_transmitter.get_latest_state_tick())

func _prepare_tick_process(tick: int) -> void:
	_history_recorder.set_latest_state_tick(_history_transmitter._latest_state_tick)

	# Save data for input prediction
	var retrieved_tick := _inputs.get_closest_tick(tick)

	# These are used as input for input age ( i.e. do we even have input, and if so, how old? )
	_has_input = retrieved_tick != -1
	_input_tick = retrieved_tick

	# Used to explicitly determine if this is a predicted tick
	# ( even if we could grab *some* input )
	_is_predicted_tick = _is_predicted_tick_for(null, tick)
	_history_transmitter.set_predicted_tick(_is_predicted_tick)

	# Reset the set of simulated and ignored nodes
	_simset.clear()
	_skipset.clear()

	# Gather nodes that can be simulated
	for node in _nodes:
		if _can_simulate(node, tick):
			NetworkRollback.notify_simulated(node)

func _can_simulate(node: Node, tick: int) -> bool:
	if not enable_prediction and _is_predicted_tick_for(node, tick):
		# Don't simulate if prediction is not allowed and tick is predicted
		return false
	if NetworkRollback.is_mutated(node, tick):
		# Mutated nodes are always resimulated
		return true
	if input_properties.is_empty():
		# If we're running inputless and own the node, simulate it if we haven't
		if node.is_multiplayer_authority():
			return tick > _last_simulated_tick
		# If we're running inputless and don't own the node, only run as prediction
		return enable_prediction
	if node.is_multiplayer_authority():
		# Simulate from earliest input
		# Don't simulate frames we don't have input for
		return tick >= _history_transmitter.get_earliest_input_tick()
	else:
		# Simulate ONLY if we have state from server
		# Simulate from latest authorative state - anything the server confirmed we don't rerun
		# Don't simulate frames we don't have input for
		return tick >= _history_transmitter.get_latest_state_tick()

# `node` can be set to null, in case we're not simulating a specific node
func _is_predicted_tick_for(node: Node, tick: int) -> bool:
	if input_properties.is_empty() and node != null:
		# We're running without inputs
		# It's only predicted if we don't own the node
		return not node.is_multiplayer_authority()
	else:
		# We have input properties, it's only predicted if we don't have the input for the tick
		return not _inputs.has(tick)

func _run_rollback_tick(tick: int) -> void:
	# Simulate rollback tick
	#	Method call on rewindables
	#	Rollback synchronizers go through each node they manage
	#	If current tick is in node's range, tick
	#		If authority: Latest input >= tick >= Latest state
	#		If not: Latest input >= tick >= Earliest input
	for node in _nodes:
		if not NetworkRollback.is_simulated(node):
			continue

		var is_fresh := _freshness_store.is_fresh(node, tick)
		_is_predicted_tick = _is_predicted_tick_for(node, tick)
		NetworkRollback.process_rollback(node, NetworkTime.ticktime, tick, is_fresh)

		if _skipset.has(node):
			continue

		_freshness_store.notify_processed(node, tick)
		_simset.add(node)

func _push_simset_metrics():
	# Push metrics
	NetworkPerformance.push_rollback_nodes_simulated(_simset.size())

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
