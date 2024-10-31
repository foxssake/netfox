@tool
@icon("res://addons/netfox.extras/icons/rewindable-state.svg")
extends Node
class_name RewindableState

## Base class for states to be used with [RewindableStateMachine].
##
## Provides multiple callback methods for a state's lifecycle, which can be 
## overridden by extending classes.
## [br][br]
## Must have a [RewindableStateMachine] as a parent.

## The [RewindableStateMachine] this state belongs to.
## [br][br]
## [i]read-only[/i]
var state_machine: RewindableStateMachine:
	get: return _state_machine

var _state_machine: RewindableStateMachine

## Callback to run a single tick.
##
## This method is called by the [RewindableStateMachine] during the rollback 
## tick loop to update game state.
## [br][br]
## [i]override[/i] to implement game logic
func tick(delta: float, tick: int, is_fresh: bool) -> void:
	pass

## Callback for entering the state.
##
## This method is called whenever the state machine enters this state.
## [br][br]
## [i]override[/i] to react to state transitions
func enter(previous_state: RewindableState, tick: int) -> void:
	pass

## Callback for entering the state.
##
## This method is called whenever the state machine exits this state.
## [br][br]
## [i]override[/i] to react to state transitions
func exit(next_state: RewindableState, tick: int) -> void:
	pass

## Callback for validating state transitions.
##
## Whenever the [RewindableStateMachine] attempts to enter this state, it will 
## call this method to ensure that the transition is valid.
## [br][br]
## If this method returns true, the transition is valid and the state machine 
## will enter this state. Otherwise, the transition is invalid, and nothing 
## happens.
## [br][br]
## [i]override[/i] to implement custom transition validation logic
func can_enter(previous_state: RewindableState) -> bool:
	# Add your validation logic here
	# Return true if the state machine can transition to the next state
	return true

func _get_configuration_warnings():
	return [] if get_parent() is RewindableStateMachine else ["This state should be a child of a RewindableStateMachine."]

func _ready():
	if _state_machine == null and get_parent() is RewindableStateMachine:
		_state_machine = get_parent()
