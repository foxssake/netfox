@icon("res://addons/netfox/icons/state-synchronizer.svg")
extends Node
class_name NetworkedStateMachine

## A networked state machine that can be used to synchronize state between peers.

@export var state: StringName = "": set = _set_state

signal state_changed(old_state: NetworkedState, new_state: NetworkedState)

# Semi-private state property
var _state_object: NetworkedState = null
var _available_states: Dictionary = {}

# Use the ready function to gather all available states
func _ready():
	for child in get_children():
		if child is NetworkedState:
			_available_states[child.name] = child

# Method to set the state
func _set_state(new_state: StringName) -> void:
	if !new_state:
		return
	
	if state == new_state:
		return
	
	if !_available_states.has(new_state):
		return
		
	var new_state_class: NetworkedState = _available_states[new_state]
	if !new_state_class:
		return
	
	if _state_object:
		if !new_state_class.can_enter(_state_object):
			return
	
		_state_object.exit()
	
	state_changed.emit(state, new_state)
	state = new_state
	_state_object = new_state_class
	_state_object.enter()

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _state_object:
		_state_object.update(delta, tick, is_fresh)

func set_state(new_state: StringName) -> void:
	state = new_state
