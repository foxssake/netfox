@tool
extends Node
class_name StateSynchronizer

## Synchronizes state from authority.
##
## Similar to Godot's [MultiplayerSynchronizer], but is tied to the network tick loop. Works well
## with [TickInterpolator].
## [br][br]
## @tutorial(StateSynchronizer Guide): https://foxssake.github.io/netfox/netfox/nodes/state-synchronizer/

## The root node for resolving node paths in properties.
@export var root: Node

## Properties to record and broadcast.
@export var properties: Array[String]

## Ticks to wait between sending full states.
## [br][br]
## If set to 0, full states will never be sent. If set to 1, only full states
## will be sent. If set higher, full states will be sent regularly, but not
## for every tick.
## [br][br]
## Only considered if [member _NetworkRollback.enable_diff_states] is true.
@export_range(0, 128, 1, "or_greater")
var full_state_interval: int = 24 # TODO: Don't tie to a network rollback setting?

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
var diff_ack_interval: int = 0 # TODO: Don't tie to a network rollback setting?

var _property_cache: PropertyCache
var _property_config: _PropertyConfig = _PropertyConfig.new()
var _properties_dirty: bool = false

var _state_history := _PropertyHistoryBuffer.new()

var _transmitter: _HistoryTransmitter

static var _logger := _NetfoxLogger.for_netfox("StateSynchronizer")

## Process settings.
## [br][br]
## Call this after any change to configuration.
func process_settings() -> void:
	_property_cache = PropertyCache.new(root)
	_property_config.set_properties_from_paths(properties, _property_cache)

	if not is_instance_valid(_transmitter):
		_transmitter = _HistoryTransmitter.new(_state_history, _property_config, _property_cache)
		add_child(_transmitter, true)
	_transmitter.process_settings(_property_cache, full_state_interval, diff_ack_interval)

## Add a state property.
## [br][br]
## Settings will be automatically updated. The [param node] may be a string or
## [NodePath] pointing to a node, or an actual [Node] instance. If the given
## property is already tracked, this method does nothing.
func add_state(node: Variant, property: String) -> void:
	var property_path := PropertyEntry.make_path(root, node, property)
	if not property_path or properties.has(property_path):
		return

	properties.push_back(property_path)
	_properties_dirty = true
	_reprocess_settings.call_deferred()

func _notification(what) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if not root:
		root = get_parent()

	# Explore state properties
	if not root:
		return ["No valid root node found!"]

	return _NetfoxEditorUtils.gather_properties(root, "_get_synchronized_state_properties",
		func(node, prop):
			add_state(node, prop)
	)

func _connect_signals() -> void:
	NetworkTime.after_tick.connect(_after_tick)
	NetworkTime.after_tick_loop.connect(_after_loop)

func _disconnect_signals() -> void:
	NetworkTime.after_tick.disconnect(_after_tick)
	NetworkTime.after_tick_loop.disconnect(_after_loop)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_connect_signals.call_deferred()
	process_settings.call_deferred()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	_disconnect_signals()

func _after_tick(_dt: float, tick: int) -> void:
	if is_multiplayer_authority():
		# Submit snapshot
		var state := _PropertySnapshot.extract(_property_config.get_properties())
		_state_history.set_snapshot(tick, state)
		_transmitter.transmit(tick)
	elif not _state_history.is_empty():
		var state := _state_history.get_history(tick)
		state.apply(_property_cache)

func _after_loop() -> void:
	_state_history.trim(NetworkTime.tick - NetworkRollback.history_limit) # TODO: Don't tie to rollback?

func _reprocess_settings() -> void:
	if not _properties_dirty:
		return

	_properties_dirty = false
	process_settings()
