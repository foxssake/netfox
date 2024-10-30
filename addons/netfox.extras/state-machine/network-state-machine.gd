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
	_logger.debug("Attempting transition %s -> %s" % [state, new_state])
	if !new_state:
		_logger.warning("%s attempted to transition but the new state name was invalid" % state)
		return
	
	if state == new_state:
		return
	
	if !_available_states.has(new_state):
		_logger.warning("Attempted to transition from state %s into non-existing state %s" % [state, new_state])
		return
		
	var new_state_class: NetworkedState = _available_states[new_state]
	
	if _state_object:
		
		if !new_state_class.can_enter(_state_object):
			return
	
		_state_object.exit(new_state_class, NetworkRollback.tick)
	
	on_state_changed.emit(_state_object, new_state_class)
	state = new_state
	var _previous_state_object: NetworkedState = _state_object
	_state_object = new_state_class
	_state_object.enter(_previous_state_object, NetworkRollback.tick)

func _set_state(new_state: StringName) -> void:
	if not new_state:
		return
	
	if not _available_states.has(new_state):
		_logger.warning("Attempted to jump to unknown state: %s" % [new_state])
		return
	
	_state_object = _available_states[new_state]
