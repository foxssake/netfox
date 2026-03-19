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
##
## @tutorial(RewindableStateMachine Guide): https://foxssake.github.io/netfox/latest/netfox.extras/guides/rewindable-state-machine/

## Name of the current state.
##
## Can be an empty string if no state is active. Only modify directly if you
## need to skip [method transition]'s callbacks.
@export var state: StringName = "":
	get: return _state_object.name if _state_object != null else ""
	set(v): _set_state(v)

## Emitted during state transitions.
##
## This signal can be used to run gameplay code on state changes.
## [br][br]
## This signal is emitted whenever a transition happens during rollback, which
## means it may be emitted multiple times for the same transition if it gets
## resimulated during rollback.
## [br][br]
## [b]State changes are not necessarily emitted on all peers.[/b]
## See: [url=https://foxssake.github.io/netfox/netfox.extras/guides/rewindable-state-machine/#caveats]RewindableStateMachine caveats[/url]
signal on_state_changed(old_state: RewindableState, new_state: RewindableState)

## Emitted after the displayed state has changed.
##
## This signal can be used to update visuals based on state changes.
## [br][br]
## This signal is emitted whenever the state after a tick loop has changed.
signal on_display_state_changed(old_state: RewindableState, new_state: RewindableState)

static var _logger: NetfoxLogger = NetfoxLogger._for_extras("RewindableStateMachine")

var _state_object: RewindableState = null
var _previous_state_object: RewindableState = null
var _available_states: Dictionary = {}
var _prevent_transition: bool = false
var _prevent_callable: Callable = func(): _prevent_transition = true

## Transition to a new state specified by [param new_state_name] and return
## true.
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
func transition(new_state_name: StringName) -> bool:
	# Check if target state is valid
	if state == new_state_name:
		return false

	if not _available_states.has(new_state_name):
		_logger.warning("Attempted to transition from state '%s' into unknown state '%s'", [state, new_state_name])
		return false

	var from_state = _state_object
	var new_state: RewindableState = _available_states[new_state_name]
	_prevent_transition = false

	# Validate transition
	if from_state:
		if !new_state.can_enter(_state_object):
			return false
		
		# Emit exit signal, allow handlers to prevent transition
		_state_object.on_exit.emit(new_state, NetworkRollback.tick, _prevent_callable)
		if _prevent_transition: return false

	new_state.on_enter.emit(from_state, NetworkRollback.tick, _prevent_callable)
	if _prevent_transition: return false
	
	# Transition valid, run callbacks
	if is_instance_valid(from_state):
		from_state.exit(new_state, NetworkRollback.tick)
	new_state.enter(from_state, NetworkRollback.tick)

	# Set new state
	_state_object = new_state
	on_state_changed.emit(from_state, new_state)

	return true

## Update the internal cache of known states
## [br][br]
## Automatically called on ready and when a child node is added or removed. Call
## manually to force an update.
func update_states() -> void:
	_available_states.clear()
	
	for child in find_children("*", "RewindableState", false):
		_available_states[child.name] = child

func _notification(what: int):
	# Use notification instead of _ready, so users can write their own _ready
	# callback without having to call super()
	if Engine.is_editor_hint(): return

	match what:
		NOTIFICATION_CHILD_ORDER_CHANGED:
			update_states()
		NOTIFICATION_ENTER_TREE:
			# Compare states after tick loop
			NetworkTime.after_tick_loop.connect(_after_tick_loop)
			update_states()
		NOTIFICATION_EXIT_TREE:
			# Disconnect handlers
			NetworkTime.after_tick_loop.disconnect(_after_tick_loop)

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
		_state_object.on_tick.emit(delta, tick, is_fresh)

func _after_tick_loop():
	if _state_object != _previous_state_object:
		on_display_state_changed.emit(_previous_state_object, _state_object)

		if _previous_state_object:
			_previous_state_object.on_display_exit.emit(_state_object, NetworkTime.tick)
			_previous_state_object.display_exit(_state_object, NetworkTime.tick)

		_state_object.on_display_enter.emit(_previous_state_object, NetworkTime.tick)
		_state_object.display_enter(_previous_state_object, NetworkTime.tick)

		_previous_state_object = _state_object

func _set_state(new_state: StringName) -> void:
	if not new_state:
		return

	if not _available_states.has(new_state):
		_logger.warning("Attempted to jump to unknown state: %s", [new_state])
		return

	_state_object = _available_states[new_state]
