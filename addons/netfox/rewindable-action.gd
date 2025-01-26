extends Node
class_name RewindableAction

# Status enum
enum {
	INACTIVE,
	CONFIRMING,
	ACTIVE,
	CANCELLING
}

var _active_ticks: _Set = _Set.new()
var _last_set_tick: int = -1
var _state_changes: Dictionary = {}
var _queued_changes: Dictionary = {}

var _has_confirmed: bool = false
var _has_cancelled: bool = false

var _context: Dictionary = {}
var _mutated_objects: _Set = _Set.new()

var _logger := _NetfoxLogger.for_netfox("RewindableAction")

signal on_confirm
signal on_cancel

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

static func status_string(status: int) -> String:
	match status:
		INACTIVE: return "INACTIVE"
		CONFIRMING: return "CONFIRMING"
		ACTIVE: return "ACTIVE"
		CANCELLING: return "CANCELLING"
		_: return "?"

func toggle(state: bool, tick: int = NetworkRollback.tick) -> void:
	_last_set_tick = tick

	if is_active(tick) == state:
		return

	# Update local state
	if tick: _active_ticks.add(tick)
	else: _active_ticks.erase(tick)

	# Fire event
	if state: on_confirm.emit()
	else: on_cancel.emit()

	# Save changes for a single loop
	_state_changes[tick] = state

func is_active(tick: int = NetworkRollback.tick) -> bool:
	return _active_ticks.has(tick)

func get_status(tick: int = NetworkRollback.tick) -> int:
	var currently_active := is_active(tick)
	var state_change = _state_changes.get(tick)
	var queued_change = _queued_changes.get(tick)

	if queued_change != null:
		return CONFIRMING if queued_change else CANCELLING
	if state_change != null:
		return CONFIRMING if state_change else CANCELLING
	return ACTIVE if currently_active else INACTIVE

func has_confirmed() -> bool:
	return _has_confirmed

func has_cancelled() -> bool:
	return _has_cancelled

func get_status_string(tick: int = NetworkRollback.tick) -> String:
	return status_string(get_status(tick))

func has_context(tick: int = NetworkRollback.tick) -> bool:
	return _context.has(tick)

func get_context(tick: int = NetworkRollback.tick) -> Variant:
	return _context.get(tick)

func set_context(value: Variant, tick: int = NetworkRollback.tick) -> void:
	_context[tick] = value

func erase_context(tick: int = NetworkRollback.tick) -> void:
	_context.erase(tick)

func mutate(target: Object) -> void:
	_mutated_objects.add(target)

func dont_mutate(target: Object) -> void:
	_mutated_objects.erase(target)

func _connect_signals() -> void:
	NetworkRollback.before_loop.connect(_before_rollback_loop)
	NetworkRollback.on_process_tick.connect(_process_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _disconnect_signals() -> void:
	NetworkRollback.before_loop.disconnect(_before_rollback_loop)
	NetworkTime.after_tick_loop.disconnect(_after_tick_loop)

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

func _process_tick(tick: int) -> void:
	if _queued_changes.has(tick):
		toggle(_queued_changes[tick])

func _after_tick_loop() -> void:
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

	# Queue earliest event
	if not _active_ticks.is_empty():
		var earliest_active = _active_ticks.min()
		for mutated in _mutated_objects:
			NetworkRollback.mutate(mutated, earliest_active)

	# Submit
	if is_multiplayer_authority() and _last_set_tick >= 0:
		var active_tick_bytes = _TicksetSerializer.serialize(NetworkRollback.history_start, _last_set_tick, _active_ticks)
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

	for tick in range(earliest_tick, latest_tick):
		var is_tick_active = active_ticks.has(tick)
		if is_tick_active != is_active(tick):
			_queued_changes[tick] = is_tick_active
