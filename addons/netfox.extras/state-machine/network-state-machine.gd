@icon("res://addons/netfox/icons/state-synchronizer.svg")
extends Node
class_name NetworkedStateMachine

## A networked state machine that can be used to synchronize state between peers.

@export var max_history_size: int = 10

signal state_changed(old_state: NetworkedState, new_state: NetworkedState)

# Semi-private state property
var _current_state: NetworkedState = null
var _current_state_name: StringName = "": set = _set_current_state_name
var _available_states: Dictionary = {}

# History buffer to store states using tick numbers as keys
var _state_history: Dictionary = {}

# Use the ready function to gather all available states
func _ready():
	for child in get_children():
		if child is NetworkedState:
			_available_states[child.name] = child

func _set_current_state_name(new_value: StringName):
	_current_state_name = new_value
	if _available_states.has(new_value):
		_current_state = _available_states[new_value]

# Method to set the state
func set_state(new_state: StringName) -> void:
	if !new_state:
		return
	
	var new_state_class: NetworkedState = _available_states[new_state]
	if !new_state_class:
		return
	
	if _current_state:
		if !new_state_class.can_enter(_current_state):
			return
	
		_current_state.exit()

		# Record the state with the current tick number
		_state_history[NetworkRollback._tick] = _current_state_name

		# Ensure history size does not exceed max_history_size
		if _state_history.size() > max_history_size:
			var keys = _state_history.keys()
			keys.sort()
			var oldest_key = keys[0]
			_state_history.erase(oldest_key)
	
	emit_signal("state_changed", _current_state_name, new_state)
	_current_state_name = new_state
	_current_state.enter()

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if NetworkRollback.is_rollback():
		if _state_history.has(tick) and _state_history.has(tick - 1):
			var previous_state = _state_history[tick - 1]
			set_state(previous_state)
			_state_history.erase(tick)

	if _current_state:
		_current_state.update(delta, tick, is_fresh)
