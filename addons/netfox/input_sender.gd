@tool
extends Node
class_name InputSender

## Stores inputs and sends them to host.
## [br][br]
##
## [InputSender] is a multi purpose node to use on networked games,
## It provides signals to code host and client side logic.
## [InputSender] signals are tied and emitted on [signal NetworkTime.on_tick].
## 
## @experimental:
## [InputSender] assumes input snapshots arrive as whole. (atomic), if snapshot
## arrives with multiple parts, [InputSender] signals wont be reliable to 
## code game logic.

## Emitted when [InputSender] receives input from remote owner of input_properties.
## [InputSender] handles applying received input internally before emitting this signal.
## Emitted only if [InputSender] has authority.
## Use this signal to code host side logic.
signal network_input(tick : int)

## Emitted for every tick if local peer has authority over input_property nodes.
## [InputSender] will apply latest local inputs for this tick internally before 
## emitting this signal.
## Use this signal to code client side logic which doesnt interfere with actual game state.
## Examples: Playing a sound, showing a visual effect.
## Dont use this signal to code same game logic on client side as it will not likely
## be same with remote host machine, it will cause syncing issues if you are already
## using some other method to syncronize game state (Syncronizers).
signal local_input(tick : int)

## Emitted when [InputSender] doesnt receive anything from client on [signal NetworkTime.on_tick]
## [InputSender] will apply latest known input internally before emitting this signal.
## Emitted only if [InputSender] is authority.
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
var _last_emitted_tick: int = -1
var _logger := NetfoxLogger._for_netfox("InputSender")

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
func _on_tick(delta: float, tick: int) -> void:
	# First handle local_input signalling.
	_apply_and_emit_local_inputs(tick)
	
	# Move on to the network_input and input_missing signalling.
	if not is_multiplayer_authority():
		return
	
	# Get the latest input data available
	# Known issue: If input sender is configured with multiple input nodes,
	# Any fresh input from one node will trigger re-emitting of other node's inputs?
	# TODO: look at above issue.
	var latest_input_tick := NetworkHistoryServer.get_latest_input_sender_for(
		_input_properties.get_subjects(), tick)
	
	if latest_input_tick == _last_emitted_tick:
		# There is no new input data available
		var latest_snapshot := NetworkHistoryServer._get_input_sender_snapshot(latest_input_tick)
		if latest_snapshot:
			_logger.trace("No new input is received, will emit input_missing after applying \
				snapshot: %s", [latest_snapshot])
			
			_apply_snapshot_for_self(latest_snapshot)
			missing_input.emit(tick, latest_input_tick)
	else:
		# Iterate over fresh inputs and emit a signal with fresh inputs applied.
		for i in range(_last_emitted_tick + 1, latest_input_tick + 1):
			var snapshot := NetworkHistoryServer._get_input_sender_snapshot(i)
			if snapshot:
				_apply_snapshot_for_self(snapshot)
				network_input.emit(i)
				_last_emitted_tick = i

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

# If the local peer has authority over input_property node, apply latest inputs
# and emit signal local_input.
func _apply_and_emit_local_inputs(for_tick : int) -> void:
	if not _has_authority_over_input_nodes():
		return
	
	var latest_local_snapshot := NetworkHistoryServer._get_input_sender_snapshot(for_tick)
	
	if latest_local_snapshot:
		_logger.trace("Applying local snapshot and emitting local_inputs: %s", [latest_local_snapshot])
		_apply_snapshot_for_self(latest_local_snapshot)
		local_input.emit(for_tick)

# Helper function to determine if InputSender has authority over its input_properties
# This function iterates over input_properties subjects and checks if they have authority.
# If none of them has authority or no input_node is configured this will return false,
# If any of them has authority this will return true instantly.
# Its developers responsibility to always make sure input_nodes have same configuration.
# TODO make sure to document this responsibility to developer.
func _has_authority_over_input_nodes() -> bool:
	for subject in _input_properties.get_subjects():
		
		# ObjectPool does not guarentee every subject is node.
		if not subject is Node:
			continue
		
		# Found input node, check if it has authority
		if subject.is_multiplayer_authority():
			return true
	
	# Did not find any node, or none of them has authority.
	return false
