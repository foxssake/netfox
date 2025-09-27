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
##
## @tutorial(RewindableStateMachine Guide): https://foxssake.github.io/netfox/latest/netfox.extras/guides/rewindable-state-machine/

## Emitted when entering the state
signal on_enter(previous_state: RewindableState, tick: int, prevent: Callable)
 
## Emitted on every rollback tick while the state is active
signal on_tick(delta: float, tick: int, is_fresh: bool)
 
## Emitted when exiting the state
signal on_exit(next_state: RewindableState, tick: int, prevent: Callable)

## Emitted before displaying this state
signal on_display_enter(previous_state: RewindableState, tick: int)

## Emitted before displaying another state
signal on_display_exit(next_state: RewindableState, tick: int)

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
## It is best practice to only modify game state here, i.e. properties that are
## configured as state in a [RollbackSynchronizer].
## [br][br]
## [i]override[/i] to implement game logic reacting to state transitions
func enter(previous_state: RewindableState, tick: int) -> void:
	pass

## Callback for exiting the state.
##
## This method is called whenever the state machine exits this state.
## [br][br]
## It is best practice to only modify game state here, i.e. properties that are
## configured as state in a [RollbackSynchronizer].
## [br][br]
## [i]override[/i] to implement game logic reacting to state transitions
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

## Callback for displaying the state.
##
## After each tick loop, the [RewindableStateMachine] checks the final state,
## i.e. the state that will be active until the next tick loop. If that state 
## has changed [b]to[/b] this one, the [RewindableStateMachine] will call this
## method.
## [br][br]
## [i]override[/i] to implement visuals / effects reacting to state transitions
func display_enter(previous_state: RewindableState, tick: int) -> void:
	pass

## Callback for displaying a different state.
##
## After each tick loop, the [RewindableStateMachine] checks the final state,
## i.e. the state that will be active until the next tick loop. If that state 
## has changed [b]from[/b] this one, the [RewindableStateMachine] will call this
## method.
## [br][br]
## [i]override[/i] to implement visuals / effects reacting to state transitions
func display_exit(next_state: RewindableState, tick: int) -> void:
	pass

func _get_configuration_warnings():
	return [] if get_parent() is RewindableStateMachine else ["This state should be a child of a RewindableStateMachine."]

func _notification(what: int):
	# Use notification instead of _ready, so users can write their own _ready 
	# callback without having to call super()
	if what == NOTIFICATION_READY:
		if _state_machine == null and get_parent() is RewindableStateMachine:
			_state_machine = get_parent()
