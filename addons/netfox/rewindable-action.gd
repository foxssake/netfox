extends Node
class_name RewindableAction

## Represents actions that may or may not happen, in a way compatible with
## rollback.
## 
## @experimental: This class is experimental!
## @tutorial(RewindableAction Guide): https://foxssake.github.io/netfox/latest/netfox/nodes/rewindable-action/

# Status enum
enum {
	INACTIVE,
	CONFIRMING,
	ACTIVE,
	CANCELLING
}

var _active_ticks: _Set = _Set.new()
var _last_set_tick: int = -1

# Maps the set of changed ticks ( int ) to their state ( active / inactive )
var _state_changes: Dictionary = {}
# Maps the set of ticks queued for change ( int ) to their state ( active / inactive )
var _queued_changes: Dictionary = {}

var _has_confirmed: bool = false
var _has_cancelled: bool = false

# Maps ticks ( int ) to context values ( any type )
var _context: Dictionary = {}
var _mutated_objects: _Set = _Set.new()

var _logger := NetfoxLogger._for_netfox("RewindableAction")

# Process:
#	@0:	Client sends an input with fire	@0
#		Client toggles action to true	@0
#		Client runs logic locally		@0
#	@1: Server receives input with fire	@0
#		Server toggles action to true	@0
#		Server broadcasts toggle		@0
#	@2: Client receives confirm			@0
#		Other clients receive toggle	@0
#		Other clients show effect		@0

## Returns the [param status] enum as string
static func status_string(status: int) -> String:
	match status:
		INACTIVE: return "INACTIVE"
		CONFIRMING: return "CONFIRMING"
		ACTIVE: return "ACTIVE"
		CANCELLING: return "CANCELLING"
		_: return "?"

## Toggles the action for a given [param tick]
func set_active(active: bool, tick: int = NetworkRollback.tick) -> void:
	_last_set_tick = tick

	if is_active(tick) == active:
		return

	# Update local state
	if active: _active_ticks.add(tick)
	else: _active_ticks.erase(tick)

	# Save changes for a single loop
	_state_changes[tick] = active

## Check if the action is happening for the given [param tick]
func is_active(tick: int = NetworkRollback.tick) -> bool:
	return _active_ticks.has(tick)

## Check the action's status for the given [param tick]
## [br][br]
## Returns [constant ACTIVE] if the action is happening.[br]
## Returns [constant INACTIVE] if the action is not happening.[br]
## Returns [constant CONFIRMING] if the action was previously known as not
## happening, but now it is.[br]
## Returns [constant CANCELLING] if the action was previously known to be
## happening, but now it is not.[br]
## [br]
## The [constant CONFIRMING] and [constant CANCELLING] statuses may occur if the
## action was just toggled, or data was received from the action's authority.
func get_status(tick: int = NetworkRollback.tick) -> int:
	var currently_active := is_active(tick)
	var state_change = _state_changes.get(tick)
	var queued_change = _queued_changes.get(tick)

	if queued_change != null:
		return CONFIRMING if queued_change else CANCELLING
	if state_change != null:
		return CONFIRMING if state_change else CANCELLING
	return ACTIVE if currently_active else INACTIVE

## Returns true if the action has been in [constant CONFIRMING] status during
## the last tick loop
func has_confirmed() -> bool:
	return _has_confirmed

## Returns true if the action has been in [constant CANCELLING] status during
## the last tick loop
func has_cancelled() -> bool:
	return _has_cancelled

## Get the action's current status as a string
## [br][br]
## See also: [member get_status]
func get_status_string(tick: int = NetworkRollback.tick) -> String:
	return status_string(get_status(tick))

## Returns true if the action has any stored context for the given [param tick]
func has_context(tick: int = NetworkRollback.tick) -> bool:
	return _context.has(tick)

## Get the context stored for the given [param tick], or null
func get_context(tick: int = NetworkRollback.tick) -> Variant:
	return _context.get(tick)

## Store [param value] as the context for the given [param tick]
func set_context(value: Variant, tick: int = NetworkRollback.tick) -> void:
	_context[tick] = value

## Erase the context for the given [param tick]
func erase_context(tick: int = NetworkRollback.tick) -> void:
	_context.erase(tick)

## Whenever the action happens, mutate the [param target] object
## [br][br]
## See also: [method _NetworkRollback.mutate]
func mutate(target: Object) -> void:
	_mutated_objects.add(target)

## Remove the [param target] object from the list of objects to [method mutate]
## [br][br]
## See also: [method _NetworkRollback.mutate]
func dont_mutate(target: Object) -> void:
	_mutated_objects.erase(target)

func _connect_signals() -> void:
	NetworkRollback.before_loop.connect(_before_rollback_loop)
	NetworkRollback.after_loop.connect(_after_loop)

func _disconnect_signals() -> void:
	NetworkRollback.before_loop.disconnect(_before_rollback_loop)
	NetworkRollback.after_loop.disconnect(_after_loop)

func _enter_tree() -> void:
	_connect_signals()

func _exit_tree() -> void:
	_disconnect_signals()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PATH_RENAMED, NOTIFICATION_ENTER_TREE:
			# Update logger name
			_logger.name = "RewindableAction:" + name

func _before_rollback_loop() -> void:
	_last_set_tick = -1

	if not _queued_changes.is_empty():
		# Resimulate from earliest change
		var earliest_change = _queued_changes.keys().min()
		NetworkRollback.notify_resimulation_start(earliest_change)
		_logger.trace("Submitted earliest tick %d from %s", [earliest_change, _queued_changes])

		# Queue mutations
		for mutated in _mutated_objects:
			NetworkRollback.mutate(mutated, earliest_change)

		# Apply queue
		for tick in _queued_changes:
			set_active(_queued_changes[tick], tick)

	# Queue earliest event
	if not _active_ticks.is_empty():
		var earliest_active = _active_ticks.min()
		for mutated in _mutated_objects:
			NetworkRollback.mutate(mutated, earliest_active)

func _after_loop() -> void:
	# Trim history
	for tick in _active_ticks:
		if tick < NetworkRollback.history_start:
			_active_ticks.erase(tick)
	for tick in _context.keys():
		if tick < NetworkRollback.history_start:
			_context.erase(tick)

	# Update confirmed / cancelled flags
	_has_confirmed =\
		_state_changes.values().any(func(it): return it == true) or \
		_queued_changes.values().any(func(it): return it == true)

	_has_cancelled =\
		_state_changes.values().any(func(it): return it == false) or \
		_queued_changes.values().any(func(it): return it == false)

	# Clear changes
	_state_changes.clear()
	_queued_changes.clear()

	# Submit
	if is_multiplayer_authority() and _last_set_tick >= 0:
		var serialize_from := NetworkRollback.history_start
		var serialize_to := _last_set_tick
		if not _active_ticks.is_empty():
			serialize_to = maxi(_active_ticks.max(), serialize_to)

		var active_tick_bytes = _TicksetSerializer.serialize(serialize_from, serialize_to, _active_ticks)
		_submit_state.rpc(active_tick_bytes)

@rpc("authority", "unreliable_ordered", "call_remote")
func _submit_state(bytes: PackedByteArray) -> void:
	# Decode incoming data
	var parsed := _TicksetSerializer.deserialize(bytes)

	var history_start: int = parsed[0]
	var last_known_tick: int = parsed[1]
	var active_ticks: _Set = parsed[2]

	# Find differences and queue changes
	var earliest_tick := maxi(history_start, NetworkRollback.history_start)
	# Don't compare past last event, as to not cancel events the host simply doesn't know about
	var latest_tick = maxi(last_known_tick, NetworkRollback.history_start)

	# Add a tolerance of 4 ticks for checking if the tickset is in the future
	# Server time might be ahead a tick or two under really small latencies,
	# e.g. LAN
	if earliest_tick > NetworkTime.tick + 4 or latest_tick > NetworkTime.tick + 4:
		_logger.debug("Received tickset for range @%d>%d, which has ticks in the future!", [earliest_tick, latest_tick])

	for tick in range(earliest_tick, latest_tick + 1):
		var is_tick_active = active_ticks.has(tick)
		if is_tick_active != is_active(tick):
			_queued_changes[tick] = is_tick_active
