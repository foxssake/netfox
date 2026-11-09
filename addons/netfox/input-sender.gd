@tool
extends Node
class_name InputSender

## Stores inputs and sends them to host.
## [br][br]
##
## [InputSender] is a multi purpose node to use on networked games. It sends
## inputs to the host, which either runs them through a [Simulator], or emits
## [signal input_applied] to run your own host side logic with them.
## [br][br]
## [b]Predicting and merging inputs[/b]: inputs are gathered once per tick,
## the same way as for rollback. Sometimes netfox needs an input that was never
## gathered, or has to fit two gathered inputs into one tick:
## [br]- [b]predict[/b]: an input is needed for a tick, but there is none. This
## happens when a client's input lead grows and a stamp is skipped, and when
## the host simulates a player whose input didn't arrive in time.
## [br]- [b]merge[/b]: two inputs get the same stamp. This happens when a
## client's input lead shrinks.
## [br]Both are rare, see [_SimulatorTimeTracker]. By default, predicting
## copies the last input, and merging keeps the newer input. If the defaults
## don't fit, implement these methods in the [member root] node's script:
## [codeblock]
## # Return the input for a tick that has none. last is the latest input
## # before it. May be called for multiple ticks in a row with the same last.
## func _predict_input(last: Dictionary) -> Dictionary:
##     var predicted := last.duplicate()
##     predicted["Input:jump"] = false
##     return predicted
##
## # Return a single input made from two inputs that got the same tick.
## # older was gathered one tick before newer.
## func _merge_input(older: Dictionary, newer: Dictionary) -> Dictionary:
##     var merged := newer.duplicate()
##     merged["Input:jump"] = older["Input:jump"] or newer["Input:jump"]
##     return merged
## [/codeblock]
## Inputs are dictionaries, with the paths in [member input_properties] as keys,
## and the input values as values. Properties missing from the returned
## dictionary keep the value from [code]last[/code] or [code]newer[/code].
## [br][br]
## For example, inputs that are only true for a single tick, like a jump press,
## are copied by default when predicting, and the press happens twice. When
## merging, the default drops the older press.

## Emitted on the host, after every tick, when the inputs of [param tick] are
## applied to the input properties. Use it to run host side logic with the
## inputs, e.g. for physics vehicles synchronized with a [StateSynchronizer].
## Whatever you change here is recorded as the state of [code]tick + 1[/code],
## the same as with [Simulator] and rollback.
## [br][br]
## Emitted for every player, including the host's own. Clients stamp their
## inputs ahead, so they're usually here in time. If they're not,
## [param is_predicted] is true, and the inputs are predicted from the latest
## ones before [param tick], see "Predicting and merging inputs" above. Inputs
## arriving after their tick was applied are never applied, the host doesn't
## change the past.
## [br][br]
## Not emitted on clients. Only emitted if something is connected to it.
## [codeblock]
## func _on_input_sender_input_applied(tick: int, is_predicted: bool) -> void:
##     engine_force = input.movement.y * engine_power
##     # Don't fire on a guessed input
##     if input.fire and not is_predicted:
##         fire(tick)
## [/codeblock]
signal input_applied(tick: int, is_predicted: bool)

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

# Nodes with a schema registered through this InputSender, see set_schema()
var _schema_nodes := _Set.new()

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

# The input before anything was gathered or applied, keyed like _get_input().
# Applied for ticks that have no input at all, e.g. right after a player
# spawned, on every peer the same way. See _SimulatorServer._apply_input_at().
var _default_input: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# DANGER we dont do deferred call here, because Simulator node depends on
	# has_authority_over_input to determine its register logic.
	# Therefore it is needed that input-sender is registered and ready to
	# return the result of that helper function.
	process_settings()

	# Reprocess authority on connect
	if NetworkEvents.enabled:
		# User might change `multiplayer` - `NetworkEvents` handles that
		NetworkEvents.on_client_start.connect(func(__): process_settings())
	else:
		multiplayer.connected_to_server.connect(process_settings)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	if not visibility_filter:
		visibility_filter = PeerVisibilityFilter.new()

	if not visibility_filter.get_parent():
		add_child(visibility_filter)

func _exit_tree():
	if Engine.is_editor_hint():
		return

	for node in _input_properties.get_subjects():
		NetworkSynchronizationServer.deregister(node)
		NetworkIdentityServer.deregister_node(node)
		NetworkHistoryServer.deregister(node)

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

	# Remember the default input. Only properties seen for the first time, so
	# reprocessing settings later never takes gathered values as defaults.
	for property_entry in _property_entries:
		var path := property_entry.to_string()
		if not _default_input.has(path):
			_default_input[path] = property_entry.get_value()

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
	InputSenderServer._deregister_input_sender(self)

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

## Set the schema for transmitting properties over the network.
## [br][br]
## The [param schema] must be a dictionary, with the keys being property path
## strings, and the values are the associated [NetworkSchemaSerializer] objects.
## Properties are interpreted relative to the [member root] node. The schema
## should contain input properties. Properties not specified in the schema will
## use a generic fallback serializer. By using the right serializer for the
## right property, bandwidth usage can be lowered.
## [br][br]
## The schema must be the same on every peer.
## [br][br]
## See [NetworkSchemas] for many common serializers.
## [br][br]
## Example:
## [codeblock]
##    input_sender.set_schema({
##        "Input:movement": NetworkSchemas.vec3f32(),
##        "Input:aim": NetworkSchemas.vec3f32(),
##        "Input:is_firing": NetworkSchemas.bool8()
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

# Returns the current input, see "Predicting and merging inputs" in the class
# description.
func _get_input() -> Dictionary:
	return _PropertySnapshot.extract(_property_entries).as_dictionary()

# Applies the given input. Properties missing from it are left unchanged.
func _set_input(input: Dictionary) -> void:
	for property_entry in _property_entries:
		var path := property_entry.to_string()
		if input.has(path):
			property_entry.set_value(input[path])

# Returns the predicted input for a tick that has none, using the root node's
# _predict_input() if it has one, see the class description.
func _get_predicted_input(last: Dictionary) -> Dictionary:
	if not root or not root.has_method("_predict_input"):
		return last.duplicate()

	var predicted: Variant = root.call("_predict_input", last.duplicate())
	if not predicted is Dictionary:
		_logger.error("_predict_input() of %s must return a Dictionary, copying the last input instead", [root.name])
		return last.duplicate()

	# Properties missing from the result keep the last value
	var result := last.duplicate()
	result.merge(predicted as Dictionary, true)
	return result

# Returns a single input made from two inputs, using the root node's
# _merge_input() if it has one, see the class description.
func _get_merged_input(older: Dictionary, newer: Dictionary) -> Dictionary:
	if not root or not root.has_method("_merge_input"):
		return newer.duplicate()

	var merged: Variant = root.call("_merge_input", older.duplicate(), newer.duplicate())
	if not merged is Dictionary:
		_logger.error("_merge_input() of %s must return a Dictionary, keeping the newer input instead", [root.name])
		return newer.duplicate()

	# Properties missing from the result keep the newer value
	var result := newer.duplicate()
	result.merge(merged as Dictionary, true)
	return result

# Helper function to save current input_properties.
# Used internally by InputSenderServer/SimulatorServer to record state before
# overwriting properties and emitting signals.
func _save_properties() -> void:
	_saved_inputs_snapshot = _PropertySnapshot.extract(_property_entries)

# Helper function to restore input_properties.
# Used internally by InputSenderServer/SimulatorServer to restore state after
# overwriting properties.
func _restore_properties() -> void:
	_saved_inputs_snapshot.apply(_property_cache)
