@icon("res://addons/netfox/icons/state-synchronizer.svg")
extends Node
class_name NetworkedStateMachine

## A networked state machine that can be used to synchronize state between peers.

@export var state: StringName = "": set = transition

signal on_state_changed(old_state: NetworkedState, new_state: NetworkedState)

static var _logger: _NetfoxLogger = _NetfoxLogger.for_extras("NetworkWeapon")

# Semi-private state property
var _state_object: NetworkedState = null
var _available_states: Dictionary = {}

# Use the ready function to gather all available states
func _ready():
	for child in find_children("*", "NetworkedState", false):
		_available_states[child.name] = child

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _state_object:
		_state_object.update(delta, tick, is_fresh)
		
# Method to set the state
func transition(new_state: StringName) -> void:
	if !new_state:
		_logger.warning("%s attempted to transition but the new state name was invalid" % state)
		return
	
	if state == new_state:
		return
	
	if !_available_states.has(new_state):
		_logger.warning("%s attempted to transition into a non-existing state" % state)
		return
		
	var new_state_class: NetworkedState = _available_states[new_state]
	
	if _state_object:
		
		if !new_state_class.can_enter(_state_object):
			return
	
		_state_object.exit()
	
	on_state_changed.emit(_state_object, new_state_class)
	state = new_state
	_state_object = new_state_class
	_state_object.enter()

func set_state(new_state: StringName) -> void:
	transition(new_state)
