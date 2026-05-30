@tool
extends Node
class_name InputSender

## Stores inputs and sends them to host.
## [br][br]
##
## [InputSender] is a multi purpose node to use on networked games,
## It provides signals to code host and client side logic.
## [InputSender] signals are tied and emitted on [signal NetworkTime.after_tick_loop].
## 
## @experimental:
## [InputSender] assumes input snapshots arrive as whole. (atomic), if snapshot
## arrives with multiple parts, [InputSender] signals wont be reliable to 
## code game logic.

## Emitted if host received input from remote owner of input_properties.
## InputSenderServer handles applying received input internally before emitting this signal.
## Use this signal to code host side logic.
signal network_input(tick : int)

## Emitted if local peer has authority over input_property nodes.
## This signal is emitted for host players too.
## InputSenderServer will apply latest local inputs for this tick internally before 
## emitting this signal.
## Use this signal to code client side logic which doesnt interfere with actual game state.
## Examples: Playing a sound, showing a visual effect.
## Dont use this signal to code same game logic on client side as it will not likely
## be same with remote host machine, it will cause syncing issues if you are already
## using some other method to syncronize game state (Syncronizers/Simulators).
signal local_input(tick : int)

## TODO check this documentation.
## Emitted if input is lost.
## Input is considered lost if its received older than missing-input-history or
## never received, under project settings netfox/input-sender.
# [signal NetworkTime.after_tick_loop].
## InputSenderServer will try to apply latest known input that comes before missing tick
## internally before emitting this signal.
## Emitted only if [InputSender] is authority.
## If host couldnt find known previous input, latest_known_input_tick will be -1.
## In that scenario, [InputSender] will not be able to have correct inputs applied.
## Use this signal to code host side prediction logic.
signal missing_input(for_tick : int, latest_known_input_tick : int)

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

var _logger := NetfoxLogger._for_netfox("InputSender")

# We need these to de-couple input-senders working logic from recording.
# InputSender applies state and emits signals, but this can change saved and synced
# input properties, to prevent that, input-sender will save its pre-logic-inputs
# and apply them whenever logic ends.
# 
# TODO we are moving to server pattern, this might be not neccessary after that.
var _saved_inputs_snapshot : _PropertySnapshot 
var _property_cache: PropertyCache
var _property_entries: Array[PropertyEntry] = []

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

func _exit_tree():
	InputSenderServer._deregister_input_sender(self)

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
	
	InputSenderServer._register_input_sender(self)

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
