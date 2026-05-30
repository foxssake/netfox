@tool
extends Node
class_name InputSender

## Stores inputs and sends them to host.
## [br][br]
##
## [InputSender] is a multi purpose node to use on networked games,
## It provides signals to code host and client side logic.
## [InputSender] signals are tied and emitted on [signal NetworkTime.on_tick].
## [InputSender] will still emit signals with tick paremeters which belongs to
## their recorded ticks.
## 
## @experimental:
## [InputSender] assumes input snapshots arrive as whole. (atomic), if snapshot
## arrives with multiple parts, [InputSender] signals wont be reliable to 
## code game logic.

## Emitted if [InputSender] received input from remote owner of input_properties.
## [InputSender] handles applying received input internally before emitting this signal.
## Emitted only if [InputSender] has authority.
## Use this signal to code host side logic.
signal network_input(tick : int)

## Emitted if local peer has authority over input_property nodes.
## [InputSender] will apply latest local inputs for this tick internally before 
## emitting this signal.
## Use this signal to code client side logic which doesnt interfere with actual game state.
## Examples: Playing a sound, showing a visual effect.
## Dont use this signal to code same game logic on client side as it will not likely
## be same with remote host machine, it will cause syncing issues if you are already
## using some other method to syncronize game state (Syncronizers).
signal local_input(tick : int)

## Emitted if [InputSender] didnt receive anything from client for a tick on
# [signal NetworkTime.on_tick].
## [InputSender] will apply latest known input that comes before missing tick
## internally before emitting this signal.
## Emitted only if [InputSender] is authority.
## If host couldnt find known previous input, latest_known_input_tick will be -1.
## In that scenario, [InputSender] will not be able to have correct inputs applied.
## Use this signal to code host side prediction logic.
signal missing_input(current_tick : int, latest_known_input_tick : int)

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

var _input_properties := _PropertyPool.new()
var _properties_dirty: bool = false

# Stored latest ticks for signals.
var _last_local_tick : int = -1
var _missing_ticks : Array[int] = []
var _missing_inputs_history_size : int = 16 

var _logger := NetfoxLogger._for_netfox("InputSender")

# We need these to de-couple input-senders working logic from recording.
# InputSender applies state and emits signals, but this can change saved and synced
# input properties, to prevent that, input-sender will save its pre-logic-inputs
# and apply them whenever logic ends.
var _saved_inputs_snapshot : _PropertySnapshot 
var _property_cache: PropertyCache
var _property_entries: Array[PropertyEntry] = []

# Flag to connect signals only once.
var _signals_connected : bool = false 

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
	
	_property_cache = PropertyCache.new(root)
	_property_entries.clear()
	
	_saved_inputs_snapshot = _PropertySnapshot.new()
	
	for property in input_properties:
		var property_entry = _property_cache.get_entry(property)
		_property_entries.push_back(property_entry)
	
	# Register identifiers
	for node in _input_properties.get_subjects():
		NetworkIdentityServer.register_node(node)
	
	# Register visibility filter
	for node in _input_properties.get_subjects():
		NetworkSynchronizationServer.register_visibility_filter(node, visibility_filter)
	
	if not _signals_connected:
		_connect_signals()
		_signals_connected = true

## Process settings based on authority.
## [br][br]
## Call this whenever the authority of input node changes.
## Make sure to do this at the same time on all peers.
func process_authority():
	
	_last_local_tick = -1
	_missing_inputs_history_size = ProjectSettings.get_setting("netfox/input_sender/missing_input_history", 16)
	_missing_ticks = []
	
	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.deregister_input_sender(node, property)
			NetworkSynchronizationServer.deregister_input_sender(node, property)
	
	# Process authority
	_input_properties.set_from_paths(root, input_properties)
	
	# Register new recorded inputs
	for node in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(node):
			NetworkHistoryServer.register_input_sender(node, property)
			NetworkSynchronizationServer.register_input_sender(node, property)

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

## Helper function to determine if [InputSender] has authority over its input_properties
## This function iterates over input_properties subjects and checks if they have authority.
## If none of them has authority or no input_node is configured this will return false,
## If any of them has authority this will return true instantly.
## Its developers responsibility to always make sure input_nodes have same configuration.
## TODO make sure to document this responsibility to developer.
func has_authority_over_input_nodes() -> bool:
	for subject in _input_properties.get_subjects():
		
		# ObjectPool does not guarentee every subject is node.
		if not subject is Node:
			continue
		
		# Found input node, check if it has authority
		if subject.is_multiplayer_authority():
			return true
	
	# Did not find any node, or none of them has authority.
	return false

## Get latest input data available for this [InputSender].
## Used by [Simulator] node internally.
func get_latest_received_information_tick(current_tick : int) -> int:
	return NetworkHistoryServer.get_latest_input_sender_for(
		_input_properties.get_subjects(),
		current_tick)

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

func _connect_signals() -> void:
	NetworkTime.on_tick.connect(_on_tick)

# Applies local snapshot and emits local_input if has authority over input nodes.
# Then
# applies new received network snapshots and emits network_input snapshots if
# [InputSender] is authority,
# If did not receive new network snapshots, applies latest and emits input_missing
# with latest snapshot.
func _on_tick(_delta: float, _tick: int) -> void:
	# Save input states to remember, this is done to avoid changing saved inputs here.
	_saved_inputs_snapshot = _PropertySnapshot.extract(_property_entries)
	
	# Handle authoritative peer first.
	if has_authority_over_input_nodes():
		_handle_authoritative_peer()
		# Apply saved inputs before returning, this prevents improper input save.
		_saved_inputs_snapshot.apply(_property_cache)
		return
	
	# Move on to the network_input and input_missing signalling.
	# input_missing and network_input signals are only emitted on host.
	if not is_multiplayer_authority():
		return
	
	_handle_host()
	# Apply saved inputs before returning, this prevents improper save.
	_saved_inputs_snapshot.apply(_property_cache)


# Helper function to apply given snapshot for only this node.
# TODO Applying whole snapshot and iterating over ticks would be nicer
# if we decide to have singleton for this
func _apply_snapshot_for_self(snapshot : _Snapshot) -> void:
	_logger.trace("Applying snapshot for self :%s", [snapshot])
	for subject in _input_properties.get_subjects():
		for property in _input_properties.get_properties_of(subject):
			
			if snapshot.has_property(subject, property):
				var value := snapshot.get_property(subject, property)
				# TODO is this should be node.set_indexed ??
				subject.set_indexed(property, value)

# If [InputSender] has multiplayer_authority, check for new or missing inputs from
# latest emitted tick and emit signals.
# This function shouldnt run if host also owns the input node.
# In that case, _handle_authoritative_peer function should run.
func _handle_host() -> void:
	# Known issue: If input sender is configured with multiple input nodes,
	# Any fresh input from one node will trigger re-emitting of other node's inputs?
	# TODO: look at above issue.
	var latest_input_tick := NetworkHistoryServer.get_latest_input_sender_for(
		_input_properties.get_subjects(), NetworkTime.tick)
	
	
	# TODO below.
	# This check right here actually doesnt make sense since inputs are always arrived
	# with latency in real life.
	# but this way or another we still need to check them in a way and loop them over
	# for missing inputs anyway so its not really that bad.
	if latest_input_tick == NetworkTime.tick:
		# We should have a snapshot
		var snapshot := NetworkHistoryServer._get_input_sender_snapshot(NetworkTime.tick)
		if snapshot:
			_logger.trace("On host applying networked snapshot and emitting network_input with\
			inputs %s", [snapshot])
			_apply_snapshot_for_self(snapshot)
			network_input.emit(NetworkTime.tick)
		else:
			# Consider input is missing
			_missing_ticks.push_back(NetworkTime.tick)
	else:
		# Consider input is missing
		_missing_ticks.push_back(NetworkTime.tick)
	
	# Now handle previously missing_inputs
	var to_erase : Array[int] = []
	
	for i in _missing_ticks:
		if NetworkTime.tick - i > _missing_inputs_history_size:
			var latest_known_tick := NetworkHistoryServer.get_latest_input_sender_for(
				_input_properties.get_subjects(), i)
			
			_logger.trace("for tick %s, latest_known_tick is %s", [i, latest_known_tick])
			
			if latest_known_tick >= 0:
				var snapshot := NetworkHistoryServer._get_input_sender_snapshot(latest_known_tick)
				_apply_snapshot_for_self(snapshot)
			
			_logger.trace("Input is missing for more than history size. Considering lost.")
			missing_input.emit(NetworkTime.tick, latest_known_tick)
			
			to_erase.push_back(i)
			continue
		
		var latest_known_tick := NetworkHistoryServer.get_latest_input_sender_for(
			_input_properties.get_subjects(), i)
		
		if latest_known_tick == i:
			# We now have information available for previously missing input.
			var snapshot := NetworkHistoryServer._get_input_sender_snapshot(latest_known_tick)
			
			if snapshot:
				# We found previously missing input.
				_logger.trace("Previously missing input snapshot now valid, emitting network_input with\
				inputs %s", [snapshot])
				_apply_snapshot_for_self(snapshot)
				network_input.emit(i)
				to_erase.push_back(i)
	
	# Clean up
	for i in to_erase:
		_missing_ticks.erase(i)

# If the local peer has authority over input node, apply latest inputs
# and emit signal local_input.
func _handle_authoritative_peer() -> void:
	var latest_tick := NetworkHistoryServer.get_latest_input_sender_for(_input_properties.get_subjects(),\
		NetworkTime.tick)
	
	# Latest tick shouldnt be -1 here anyway since we have information available as local player
	# But leave this here until we have more stable structure.
	if latest_tick == -1:
		_logger.error("Authoritative peer doesnt have any local input snapshot! This shouldnt happen.")
		return
	
	var tick_start_inclusive : int = -1
	var tick_end_inclusive : int = NetworkTime.tick
	
	# If this is first iteration, start from current tick, else +1
	if _last_local_tick == -1:
		tick_start_inclusive = NetworkTime.tick - 1
	else:
		tick_start_inclusive = _last_local_tick + 1
	
	_logger.trace("On authoritative peer, iterating over new inputs and emitting local_input, \
	ticks to handle %s", [tick_end_inclusive - tick_start_inclusive])
	
	for i in range(tick_start_inclusive, tick_end_inclusive + 1, 1):
		var local_snapshot := NetworkHistoryServer._get_input_sender_snapshot(i)
		
		if local_snapshot:
			_logger.trace("Applying local snapshot and emitting local_inputs: %s", [local_snapshot])
			_apply_snapshot_for_self(local_snapshot)
			local_input.emit(i)
			_last_local_tick = i
