@tool
@icon("res://addons/netfox.extras/icons/rewindable-state-machine.svg")
extends Node
class_name RewindableStateMachine

## A state machine that can be used with rollback.
##
## It relies on [RollbackSynchronizer] to manage its state. State transitions 
## are only triggered by gameplay code, and not by rollback reverting to an 
## earlier state.
## [br][br]
## For this node to work correctly, a [RollbackSynchronizer] must be added as 
## a sibling, and it must have the [RewindableStateMachine]'s [member state] 
## property configured as a state property.
## [br][br]
## To implement states, extend the [RewindableState] class and add it as a child
## node.

## Name of the current state.
## 
## Can be an empty string if no state is active. Only modify directly if you
## need to skip [method transition]'s callbacks. 
@export var state: StringName = "":
	get: return _state_object.name if _state_object != null else ""
	set(v): transition(v, true)

## Emitted after the tick loop when the state has changed.
##
## This signal is emitted whenever a tick has finished and the state has changed, which 
## means it will only emit once per tick. Ideal for updating displays or making quick changes without further simulation.
signal after_tick_state_changed(old_state: RewindableState, new_state: RewindableState)

static var _logger: _NetfoxLogger = _NetfoxLogger.for_extras("RewindableStateMachine")

var _state_object: RewindableState = null
var _previous_tick_state: RewindableState = null
var _available_states: Dictionary = {}

## Transition to a new state specified by [param new_state_name].
##
## Finds the given state by name and transitions to it if possible. The new 
## state's [method RewindableState.can_enter] callback decides if it can be
## entered from the current state.
## [br][br]
## Upon transitioning, [method RewindableState.exit] is called on the old state,
## and [method RewindableState.enter] is called on the new state. In addition, 
## [signal on_state_changed] is emitted.
## [br][br]
## Does nothing if transitioning to the currently active state. Emits a warning
## and does nothing when transitioning to an unknown state.
func transition(new_state_name: StringName, is_rollback: bool = false) -> void:
	if state == new_state_name:
		return
	
	if not _available_states.has(new_state_name):
		_logger.warning("Attempted to transition from state '%s' into unknown state '%s'", [state, new_state_name])
		return
		
	var new_state: RewindableState = _available_states[new_state_name]
	if _state_object:
		if !is_rollback and !new_state.can_enter(_state_object):
			return
	
		_state_object.exit(new_state, NetworkRollback.tick, is_rollback)
	
	var _previous_state: RewindableState = _state_object
	_state_object = new_state
	_state_object.enter(_previous_state, NetworkRollback.tick, is_rollback)

func _notification(what: int):
	if what == NOTIFICATION_READY:
		# Gather known states
		for child in find_children("*", "RewindableState", false):
			_available_states[child.name] = child
			
		NetworkTime.after_tick_loop.connect(func ():
			if _state_object != _previous_tick_state:
				after_tick_state_changed.emit(_previous_tick_state, _state_object)
				_previous_tick_state = _state_object
		)

func _get_configuration_warnings():
	const MISSING_SYNCHRONIZER_ERROR := \
		"RewindableStateMachine is not managed by a RollbackSynchronizer! Add it as a sibling node to fix this."
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
		_state_object.tick(delta, tick, is_fresh)
