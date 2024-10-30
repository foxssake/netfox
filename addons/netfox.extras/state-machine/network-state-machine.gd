@tool
@icon("res://addons/netfox/icons/state-synchronizer.svg")
extends Node
class_name NetworkedStateMachine

## A networked state machine that can be used to synchronize state between peers.

@export var state: StringName = "":
	get: return _state_object.name if _state_object != null else ""
	set(v): _set_state(v)

signal on_state_changed(old_state: NetworkedState, new_state: NetworkedState)

static var _logger: _NetfoxLogger = _NetfoxLogger.for_extras("NetworkedStateMachine")

var _state_object: NetworkedState = null
var _available_states: Dictionary = {}

func transition(new_state_name: StringName) -> void:
	if state == new_state_name:
		return
	
	if not _available_states.has(new_state_name):
		_logger.warning("Attempted to transition from state '%s' into unknown state '%s'" % [state, new_state_name])
		return
		
	var new_state: NetworkedState = _available_states[new_state_name]
	if _state_object:
		if !new_state.can_enter(_state_object):
			return
	
		_state_object.exit(new_state, NetworkRollback.tick)
	
	var _previous_state: NetworkedState = _state_object
	_state_object = new_state
	on_state_changed.emit(_previous_state, new_state)
	_state_object.enter(_previous_state, NetworkRollback.tick)

func _ready():
	# Gather known states
	for child in find_children("*", "NetworkedState", false):
		_available_states[child.name] = child

func _get_configuration_warnings():
	const MISSING_SYNCHRONIZER_ERROR := \
		"NetworkedStateMachine is not managed by a RollbackSynchronizer! Add it as a sibling node to fix this."
	const INVALID_SYNCHRONIZER_CONFIG_ERROR := \
		"RollbackSynchronizer configuration is invalid, it can't manage this state machine!" +\
		"\nNote: You may need to reload this scene after fixing for this warning to disappear."
	const MISSING_PROPERTY_ERROR := \
		"State is not managed by RollbackSynchronizer! Add `state` property to the synchronizer to fix this. " +\
		"\nNote: You may need to reload this scene after fixing for this warning to disappear."
	
	# Check if there's a rollback synchronizer
	var rollback_synchronizer_node = get_parent().find_children("*", "RollbackSynchronizer", false).pop_front()
	if not rollback_synchronizer_node:
		return [MISSING_SYNCHRONIZER_ERROR]
	
	var rollback_synchronizer := rollback_synchronizer_node as RollbackSynchronizer
	
	# Check if its configuration is valid
	# TODO: Expose this as a property?
	if not rollback_synchronizer.root:
		return [INVALID_SYNCHRONIZER_CONFIG_ERROR]
	
	# Check if it manages our `state` property
	for state_property_path in rollback_synchronizer.state_properties:
		var property = PropertyEntry.parse(rollback_synchronizer.root, state_property_path)
		if property.node == self and property.property == "state":
			return []

	return [MISSING_PROPERTY_ERROR]

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _state_object:
		_state_object.update(delta, tick, is_fresh)

func _set_state(new_state: StringName) -> void:
	if not new_state:
		return
	
	if not _available_states.has(new_state):
		_logger.warning("Attempted to jump to unknown state: %s" % [new_state])
		return
	
	_state_object = _available_states[new_state]
