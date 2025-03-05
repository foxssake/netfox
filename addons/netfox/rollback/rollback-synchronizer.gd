@tool
extends Node
class_name RollbackSynchronizer

## Similar to [MultiplayerSynchronizer], this class is responsible for
## synchronizing data between players, but with support for rollback.
## [br][br]
## @tutorial(RollbackSynchronizer Guide): https://foxssake.github.io/netfox/netfox/nodes/rollback-synchronizer/

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

var _record_state_property_entries: Array[PropertyEntry] = []
var _record_input_property_entries: Array[PropertyEntry] = []
var _auth_state_property_entries: Array[PropertyEntry] = []
var _auth_input_property_entries: Array[PropertyEntry] = []
var _nodes: Array[Node] = []

var _simset: _Set = _Set.new()
var _skipset: _Set = _Set.new()

var _properties_dirty: bool = false

var _states := _PropertyHistoryBuffer.new()
var _inputs := _PropertyHistoryBuffer.new()
var _latest_state_tick: int
var _earliest_input_tick: int

# Maps peers (int) to acknowledged ticks (int)
var _ackd_state: Dictionary = {}
var _next_full_state_tick: int
var _next_diff_ack_tick: int

var _has_input: bool
var _input_tick: int
var _is_predicted_tick: bool

var _property_cache: PropertyCache
var _freshness_store: RollbackFreshnessStore

var _is_initialized: bool = false

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("RollbackSynchronizer")

signal _on_transmit_state(state: Dictionary, tick: int)

## Process settings.
##
## Call this after any change to configuration. Updates based on authority too
## ( calls process_authority ).
func process_settings() -> void:
	_property_cache = PropertyCache.new(root)
	_freshness_store = RollbackFreshnessStore.new()

	_nodes.clear()
	_record_state_property_entries.clear()

	_states.clear()
	_inputs.clear()
	_ackd_state.clear()
	_latest_state_tick = NetworkTime.tick - 1
	_earliest_input_tick = NetworkTime.tick
	_next_full_state_tick = NetworkTime.tick
	_next_diff_ack_tick = NetworkTime.tick

	# Scatter full state sends, so not all nodes send at the same tick
	if is_inside_tree():
		_next_full_state_tick += hash(get_path()) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(get_path()) % maxi(1, diff_ack_interval)
	else:
		_next_full_state_tick += hash(name) % maxi(1, full_state_interval)
		_next_diff_ack_tick += hash(name) % maxi(1, diff_ack_interval)

	# Gather state properties - all state properties are recorded
	for property in state_properties:
		var property_entry := _property_cache.get_entry(property)
		_record_state_property_entries.push_back(property_entry)

	process_authority()

	# Gather all rollback-aware nodes to simulate during rollbacks
	_nodes = root.find_children("*")
	_nodes.push_front(root)
	_nodes = _nodes.filter(func(it): return NetworkRollback.is_rollback_aware(it))
	_nodes.erase(self)

	_is_initialized = true

## Process settings based on authority.
##
## Call this whenever the authority of any of the nodes managed by
## RollbackSynchronizer changes. Make sure to do this at the same time on all
## peers.
func process_authority() -> void:
	_record_input_property_entries.clear()
	_auth_input_property_entries.clear()
	_auth_state_property_entries.clear()

	# Gather state properties that we own
	# i.e. it's the state of a node that belongs to the local peer
	for property in state_properties:
		var property_entry := _property_cache.get_entry(property)
		if property_entry.node.is_multiplayer_authority():
			_auth_state_property_entries.push_back(property_entry)

	# Gather input properties that we own
	# Only record input that is our own
	for property in input_properties:
		var property_entry := _property_cache.get_entry(property)
		if property_entry.node.is_multiplayer_authority():
			_auth_input_property_entries.push_back(property_entry)
			_record_input_property_entries.push_back(property_entry)

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
	return _latest_state_tick

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync

	# Dummy states to parse for first inputs before our first real input
	# Empty inputs don't change any properties
	for i in NetworkRollback.input_delay:
		_inputs.set_snapshot(NetworkTime.tick + i, {})

	process_settings.call_deferred()

func _connect_signals() -> void:
	NetworkTime.before_tick.connect(_before_tick)
	NetworkTime.after_tick.connect(_after_tick)
	NetworkRollback.before_loop.connect(_before_loop)
	NetworkRollback.on_prepare_tick.connect(_prepare_tick)
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkRollback.on_record_tick.connect(_record_tick)
	NetworkRollback.after_loop.connect(_after_loop)

func _disconnect_signals() -> void:
	NetworkTime.before_tick.disconnect(_before_tick)
	NetworkTime.after_tick.disconnect(_after_tick)
	NetworkRollback.before_loop.disconnect(_before_loop)
	NetworkRollback.on_prepare_tick.disconnect(_prepare_tick)
	NetworkRollback.on_process_tick.disconnect(_process_tick)
	NetworkRollback.on_record_tick.disconnect(_record_tick)
	NetworkRollback.after_loop.disconnect(_after_loop)

func _notification(what) -> void:
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

	if not NetworkTime.is_initial_sync_done():
		# Wait for time sync to complete
		await NetworkTime.after_sync
	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_is_initialized = false
	_disconnect_signals()

func _before_loop() -> void:
	if _auth_input_property_entries.is_empty():
		# We don't have any inputs we own, simulate from earliest we've received
		NetworkRollback.notify_resimulation_start(_earliest_input_tick)
	else:
		# We own inputs, simulate from latest authorative state
		NetworkRollback.notify_resimulation_start(_latest_state_tick)

func _prepare_tick(tick: int) -> void:
	# Prepare state
	#	Done individually by Rewindables ( usually Rollback Synchronizers )
	#	Restore input and state for tick
	var retrieved_tick := _inputs.get_closest_tick(tick)
	var state := _states.get_history(tick)
	var input := _inputs.get_history(tick)

	state.apply(_property_cache)
	input.apply(_property_cache)

	# Save data for input prediction
	_has_input = retrieved_tick != -1
	_input_tick = retrieved_tick
	_is_predicted_tick = not _inputs.has(tick)

	# Reset the set of simulated and ignored nodes
	_simset.clear()
	_skipset.clear()

	# Gather nodes that can be simulated
	for node in _nodes:
		if _can_simulate(node, tick):
			NetworkRollback.notify_simulated(node)

func _can_simulate(node: Node, tick: int) -> bool:
	if not enable_prediction and not _inputs.has(tick):
		# Don't simulate if prediction is not allowed and input is unknown
		return false
	if NetworkRollback.is_mutated(node, tick):
		# Mutated nodes are always resimulated
		return true
	if node.is_multiplayer_authority():
		# Simulate from earliest input
		# Don't simulate frames we don't have input for
		return tick >= _earliest_input_tick
	else:
		# Simulate ONLY if we have state from server
		# Simulate from latest authorative state - anything the server confirmed we don't rerun
		# Don't simulate frames we don't have input for
		return tick >= _latest_state_tick

func _process_tick(tick: int) -> void:
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
		NetworkRollback.process_rollback(node, NetworkTime.ticktime, tick, is_fresh)

		if _skipset.has(node):
			continue

		_freshness_store.notify_processed(node, tick)
		_simset.add(node)

func _record_tick(tick: int) -> void:
	# Broadcast state we own
	if not _auth_state_property_entries.is_empty() and not _is_predicted_tick:
		var full_state := _PropertySnapshot.new()

		for property in _auth_state_property_entries:
			if _can_simulate(property.node, tick - 1) \
				and not _skipset.has(property.node) \
				or NetworkRollback.is_mutated(property.node, tick - 1):
				# Only broadcast if we've simulated the node
				# NOTE: _can_simulate checks mutations, but to override _skipset
				# we check a second time
				full_state.set_value(property.to_string(), property.get_value())

		_on_transmit_state.emit(full_state, tick)

		if full_state.size() > 0:
			_latest_state_tick = max(_latest_state_tick, tick)

			_states.merge(full_state, tick)

			if not NetworkRollback.enable_diff_states:
				# Broadcast new full state
				_submit_full_state.rpc(full_state.as_dictionary(), tick)

				NetworkPerformance.push_full_state_broadcast(full_state.as_dictionary())
				NetworkPerformance.push_sent_state_broadcast(full_state.as_dictionary())
			elif full_state_interval > 0 and tick > _next_full_state_tick:
				# Send full state so we can send deltas from there
				_logger.trace("Broadcasting full state for tick %d", [tick])
				_submit_full_state.rpc(full_state.as_dictionary(), tick)
				_next_full_state_tick = tick + full_state_interval

				NetworkPerformance.push_full_state_broadcast(full_state.as_dictionary())
				NetworkPerformance.push_sent_state_broadcast(full_state.as_dictionary())
			else:
				for peer in multiplayer.get_peers():
					NetworkPerformance.push_full_state(full_state.as_dictionary())

					# Peer hasn't received a full state yet, can't send diffs
					if not _ackd_state.has(peer):
						_submit_full_state.rpc_id(peer, full_state.as_dictionary(), tick)
						NetworkPerformance.push_sent_state(full_state.as_dictionary())
						continue

					# History doesn't have reference tick?
					var reference_tick = _ackd_state[peer]
					if not _states.has(reference_tick):
						_submit_full_state.rpc_id(peer, full_state.as_dictionary(), tick)
						NetworkPerformance.push_sent_state(full_state.as_dictionary())
						continue

					# Prepare diff and send
					var reference_state := _states.get_history(reference_tick)
					var diff_state := reference_state.make_patch(full_state)

					if diff_state.size() == full_state.size():
						# State is completely different, send full state
						_submit_full_state.rpc_id(peer, full_state.as_dictionary(), tick)
						NetworkPerformance.push_sent_state(full_state.as_dictionary())
					else:
						# Send only diff
						_submit_diff_state.rpc_id(peer, diff_state.as_dictionary(), tick, reference_tick)
						NetworkPerformance.push_sent_state(diff_state.as_dictionary())

	# Record state for specified tick ( current + 1 )

	# Check if any of the managed nodes were mutated
	var is_mutated := _record_state_property_entries.any(func(pe):
		return NetworkRollback.is_mutated(pe.node, tick - 1))

	# Record if there's any properties to record and we're past the latest known state OR something
	# was mutated
	if not _record_state_property_entries.is_empty() and (tick > _latest_state_tick or is_mutated):
		if _skipset.is_empty():
			_states.set_snapshot(tick, _PropertySnapshot.extract(_record_state_property_entries))
		else:
			var record_properties = _record_state_property_entries\
				.filter(func(pe): return \
					not _skipset.has(pe.node) or \
					NetworkRollback.is_mutated(pe.node, tick - 1))

			var merge_state := _states.get_history(tick - 1)
			var record_state := _PropertySnapshot.extract(record_properties)

			_states.set_snapshot(tick, merge_state.merge(record_state))

	# Push metrics
	NetworkPerformance.push_rollback_nodes_simulated(_simset.size())

func _after_loop() -> void:
	_earliest_input_tick = NetworkTime.tick

	# Apply display state
	var display_state := _states.get_history(NetworkRollback.display_tick)
	display_state.apply(_property_cache)

func _before_tick(_delta: float, tick: int) -> void:
	# Apply state for tick
	var state = _states.get_history(tick)
	state.apply(_property_cache)

func _after_tick(_delta: float, _tick: int) -> void:
	# Record input
	if not _record_input_property_entries.is_empty():
		var input := _PropertySnapshot.extract(_record_input_property_entries)
		var input_tick: int = _tick + NetworkRollback.input_delay
		_inputs.set_snapshot(input_tick, input)

		# Send the last n inputs for each property
		var inputs: Array[_PropertySnapshot] = []
		for i in range(0, mini(NetworkRollback.input_redundancy, _inputs.size())):
			var tick := input_tick - i
			inputs.append(_inputs.get_snapshot(tick))
		_attempt_submit_inputs(inputs, input_tick)

	# Trim history
	_states.trim()
	_inputs.trim()
	_freshness_store.trim()

func _attempt_submit_inputs(inputs: Array[_PropertySnapshot], input_tick: int) -> void:

	var serialized_inputs : Array[Dictionary] = []
	for input in inputs:
		serialized_inputs.push_back(input.as_dictionary())

	# TODO: Default to input broadcast in mesh network setups
	if enable_input_broadcast:
		_submit_inputs.rpc(serialized_inputs, input_tick)
	elif not multiplayer.is_server():
		_submit_inputs.rpc_id(1, serialized_inputs, input_tick)

func _reprocess_settings() -> void:
	if not _properties_dirty or Engine.is_editor_hint():
		return

	_properties_dirty = false
	process_settings()

@rpc("any_peer", "unreliable", "call_remote")
func _submit_inputs(serialized_inputs: Array, tick: int) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var inputs : Array[_PropertySnapshot] = []

	for input in serialized_inputs:
		inputs.push_back(_PropertySnapshot.from_dictionary(input))

	var sender := multiplayer.get_remote_sender_id()

	for offset in range(inputs.size()):
		var input_tick := tick - offset

		if input_tick < NetworkRollback.history_start:
			# Input too old
			_logger.warning("Received input for %s, rejecting because older than %s frames", [input_tick, NetworkRollback.history_limit])
			continue

		var input := inputs[offset]
		if input == null:
			# We've somehow received a null input - shouldn't happen
			_logger.error("Null input received for %d, full batch is %s", [input_tick, serialized_inputs])
			continue

		input.sanitize(sender, _property_cache)

		if input.is_empty():
			_logger.warning("Received invalid input from %s for tick %s for %s" % [sender, tick, root.name])
			return

		var known_input := _inputs.get_snapshot(input_tick)
		if not known_input.equals(input):
			# Received a new input, save to history
			_inputs.set_snapshot(input_tick, input)
			_earliest_input_tick = mini(_earliest_input_tick, input_tick)


# `serialized_state` is a serialized _PropertySnapshot
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_full_state(serialized_state: Dictionary, tick: int) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var state := _PropertySnapshot.from_dictionary(serialized_state)

	if tick < NetworkRollback.history_start:
		# State too old!
		_logger.error("Received full state for %s, rejecting because older than %s frames", [tick, NetworkRollback.history_limit])
		return

	var sender := multiplayer.get_remote_sender_id()
	state.sanitize(sender, _property_cache)

	if state.is_empty():
		# State is completely invalid
		_logger.warning("Received invalid state from %s for tick %s", [sender, tick])
		return

	_states.merge(state, tick)
	_latest_state_tick = tick

	if NetworkRollback.enable_diff_states:
		_ack_full_state.rpc_id(sender, tick)

# State is a serialized _PropertySnapshot (Dictionary[String, Variant])
@rpc("any_peer", "unreliable_ordered", "call_remote")
func _submit_diff_state(serialized_diff_state: Dictionary, tick: int, reference_tick: int) -> void:
	if not _is_initialized:
		# Settings not processed yet
		return

	var diff_state := _PropertySnapshot.from_dictionary(serialized_diff_state)

	if tick < NetworkTime.tick - NetworkRollback.history_limit:
		# State too old!
		_logger.error("Received diff state for %s, rejecting because older than %s frames", [tick, NetworkRollback.history_limit])
		return

	if not _states.has(reference_tick):
		# Reference tick missing, hope for the best
		_logger.warning("Reference tick %d missing for %d", [reference_tick, tick])

	var sender := multiplayer.get_remote_sender_id()
	var reference_state := _states.get_snapshot(reference_tick)
	var is_valid_state := true

	if serialized_diff_state.is_empty():
		_latest_state_tick = tick
		_states.merge(reference_state, tick)
	else:
		diff_state.sanitize(sender, _property_cache)

		if diff_state.is_empty():
			# State is completely invalid
			_logger.warning("Received invalid state from %s for tick %s", [sender, tick])
			is_valid_state = false
		else:
			var result_state := reference_state.merge(diff_state)
			_states.set_snapshot(tick, result_state)
			_latest_state_tick = tick

	if NetworkRollback.enable_diff_states:
		if is_valid_state and diff_ack_interval > 0 and tick > _next_diff_ack_tick:
			_ack_diff_state.rpc_id(sender, tick)
			_next_diff_ack_tick = tick + diff_ack_interval

@rpc("any_peer", "reliable", "call_remote")
func _ack_full_state(tick: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd full state for tick %d", [sender_id, tick])

@rpc("any_peer", "unreliable_ordered", "call_remote")
func _ack_diff_state(tick: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_ackd_state[sender_id] = tick

	_logger.trace("Peer %d ack'd diff state for tick %d", [sender_id, tick])
