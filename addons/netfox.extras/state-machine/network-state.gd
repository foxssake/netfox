@tool
@icon("res://addons/netfox/icons/state-synchronizer.svg")
extends Node
class_name NetworkedState

var state_machine: NetworkedStateMachine

## A networked state for use with [NetworkedStateMachine].

func _get_configuration_warnings():
	return [] if get_parent() is NetworkedStateMachine else ["This state should be a child of a NetworkedStateMachine."]

func _ready():
	if state_machine == null and get_parent() is NetworkedStateMachine:
		state_machine = get_parent()

# Custom update callback method
func update(delta: float, tick: int, is_fresh: bool) -> void:
	pass

# Callback for entering the state
func enter(_previous_state: NetworkedState, tick: int) -> void:
	pass

# Callback for exiting the state
func exit(_next_state: NetworkedState, tick: int) -> void:
	pass

# Callback to validate transitions
func can_enter(previous_state: NetworkedState) -> bool:
	# Add your validation logic here
	# Return true if the state machine can transition to the next state
	return true
