@icon("res://addons/netfox/icons/state-synchronizer.svg")
extends Node
class_name NetworkedState

@export var state_machine: NetworkedStateMachine

## A networked state for use with [NetworkedStateMachine].

func _ready():
	if state_machine == null and get_parent() is NetworkedStateMachine:
		state_machine = get_parent()

# Custom update callback method
func update(delta: float, tick: int, is_fresh: bool) -> void:
	pass

# Custom physics process callback method
func physics_process(delta: float) -> void:
	pass

# Callback for entering the state
func enter() -> void:
	pass

# Callback for exiting the state
func exit() -> void:
	pass

# Callback to validate transitions
func can_enter(previous_state: NetworkedState) -> bool:
	# Add your validation logic here
	# Return true if the state machine can transition to the next state
	return true
