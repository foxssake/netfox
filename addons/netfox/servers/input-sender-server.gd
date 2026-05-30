extends Node
class_name _InputSenderServer

# @public class

## Handles [InputSender] related operations.

## InputSenderServer assumes input snapshots arrive as whole. (atomic), if snapshot
## arrives with multiple parts, [InputSender] signals wont be reliable to 
## code game logic.

## TODO TODO TODO
## 1- Dont forget to restore input sender state after tick loop.
## 2- Handle local inputs on tick? or after_tick_loop

static var _logger := NetfoxLogger._for_netfox("InputSenderServer")

var _history_server : NetworkHistoryServer = null
var _synchronization_server : NetworkSynchronizationServer = null
var _missing_inputs_history_size : int = 16 
var _earliest_input := -1

# Maps InputSender -> InputSenderHistory (inner class, look at the end of this script.)
var _per_input_sender_history : Dictionary = {}

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _synchronization_server: _synchronization_server = NetworkSynchronizationServer
	
	_missing_inputs_history_size = ProjectSettings.get_setting("netfox/input_sender/missing_input_history", 16)
	
	# Record inputs similiar to rollback so that users can use same methods
	# on their input scripts.
	NetworkTime.after_tick.connect(func(_dt, tick):
		_history_server._record_input_sender(tick)
		_synchronization_server._synchronize_input_sender(tick)
	)
	
	_synchronization_server._on_input_sender.connect(_on_received_input_snapshot)
	
	# About when we should process our inputs:
	# It doesnt make sense to process them when we receive them, as it will break the
	# work order of [Simulator]s or [TickInterpolator]s, or we might want this to work
	# with physics. It would be unreliable.
	# Therefore we need to process them in a fixed point.
	# Processing them on every tick doesnt make sense, since host may run multiple
	# ticks and we probably wont even have new inputs to process anyway.
	# In conculusion it makes sense to process them after a tick loop run.
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

# Whenever we receive input snapshot, we investigate and fetch _earliest_input tick
# This is later used to iterate over saved snapshots and emit signals.
func _on_received_input_snapshot(snapshot : _Snapshot) -> void:
	if snapshot.is_empty():
		return
	if _earliest_input < 0 or snapshot.tick < _earliest_input:
		_logger.trace("Ingested input @%d, earliest @%d->@%d", [snapshot.tick, _earliest_input, snapshot.tick])
		_earliest_input = snapshot.tick
	else:
		_logger.trace("Ingested input @%d, earliest @%d->@%d", [snapshot.tick, _earliest_input, _earliest_input])

# After a tick loop has been run,
# Iterate over snapshots to catch if host received new inputs.
# If so, apply and emit a signal for it via InputSender node so users code can run.
func _after_tick_loop() -> void:
	if _earliest_input < 0:
		return
	
	var current_tick : int = NetworkTime.tick
	
	for i in range(_earliest_input, current_tick + 1):
		
		if i < current_tick - _missing_inputs_history_size:
			# i is older than our history size.
			# We need to emit input_missing
			
			for input_sender in _per_input_sender_history.keys():
				if _is_there_new_input_for_input_sender(input_sender, i):
					# Even if there is new input available, it past our history size
					# Apply it and emit input missing.
					var snapshot = _history_server._get_input_sender_snapshot(i)
					if snapshot:
						input_sender._apply_snapshot_for_self(snapshot)
						input_sender.missing_input.emit(i, i)
					else:
						var latest_tick = _history_server.get_latest_input_sender_for(
							input_sender._input_properties.get_subjects(), i)
						
						var latest_snapshot := _history_server._get_input_sender_snapshot(latest_tick)
						
						if latest_snapshot:
							# Found previous snapshot relative to missing input.
							input_sender._apply_snapshot_for_self(latest_snapshot)
							input_sender.missing_input.emit(i, latest_tick)
						else:
							# Couldnt even foind previous input
							input_sender.missing_input.emit(i, -1)
					
					_set_input_received_for_input_sender(input_sender, i)
			
			# We iterated over input_senders and emitted missing input because tick is old
			# now continue since there is nothing left to do at old ticks.
			continue
		
		#..
		#..
		#.
		# Tick i is not older than our history size.
		# Iterate over input senders and check if they have new information available.
		
		for input_sender in _per_input_sender_history.keys():
			if not _is_there_new_input_for_input_sender(input_sender, i):
				continue
			
			# Did not received before
			# Received new information for this input sender.
			var snapshot := _history_server._get_input_sender_snapshot(i)
			if snapshot:
				input_sender._apply_snapshot_for_self(snapshot)
				input_sender.network_input.emit(i)
				_set_input_received_for_input_sender(input_sender, i)
	
	# Erase old history
	for history in _per_input_sender_history.values():
		history.erase_old_ticks(current_tick - _missing_inputs_history_size)
	
	# Reset earliest_input.
	_earliest_input = -1

func _register_input_sender(input_sender : InputSender) -> void:
	_per_input_sender_history[input_sender] = InputSenderHistory.new()

func _deregister_input_sender(input_sender : InputSender) -> void:
	_per_input_sender_history.erase(input_sender)

# Helper that sets input received for param input sender on given tick.
func _set_input_received_for_input_sender(input_sender : InputSender, tick : int) -> void:
	var history : InputSenderHistory = _per_input_sender_history[input_sender] as InputSenderHistory
	if history:
		history.set_as_received_for_tick(tick)

## Check if there is a new input available for given input sender on given tick.
func _is_there_new_input_for_input_sender(input_sender : InputSender, tick : int) -> bool:
	var history : InputSenderHistory = _per_input_sender_history[input_sender] as InputSenderHistory
	var received_before := history.did_receive_for_tick(tick)
	
	if received_before:
		return false
	
	# We need to check if snapshot has this input senders properties
	var snapshot := _history_server._get_input_sender_snapshot(tick)
	if snapshot:
		for property_entry in input_sender._property_entries:
			if snapshot.has_property(property_entry.node, property_entry.property):
				# There is new information available indeed
				return true
	
	# No new information
	return false

func _init(p_history_server: _NetworkHistoryServer = null, p_synchronization_server: _NetworkSynchronizationServer = null):
	_history_server = p_history_server
	_synchronization_server = p_synchronization_server

## Inner class to remember and compare
## Did we receive any input before for given tick?
## stored for specific InputSender.
class InputSenderHistory extends RefCounted:
	
	# Maps ticks to bool (we received input before = true, never received = false)
	var _history : Dictionary = {}
	
	## Set param tick as received
	func set_as_received_for_tick(tick : int) -> void:
		_history[tick] = true
	
	## Check if we received input for given tick.
	## Returns false if we dont have information for that tick.
	func did_receive_for_tick(tick : int) -> bool:
		return _history.get(tick, false)
	
	## Erase old ticks that we dont need anymore.
	func erase_old_ticks(older_than_inclusive : int) -> void:
		var to_erase : Array[int] = []
		for tick in _history.keys():
			if tick <= older_than_inclusive:
				to_erase.push_back(tick)
		
		for erase_tick in to_erase:
			_history.erase(erase_tick)
