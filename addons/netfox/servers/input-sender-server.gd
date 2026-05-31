extends Node
class_name _InputSenderServer

# @public class

## Handles [InputSender] related operations.

## InputSenderServer assumes input snapshots arrive as whole. (atomic), if snapshot
## arrives with multiple parts, [InputSender] signals wont be reliable to 
## code game logic.

static var _logger := NetfoxLogger._for_netfox("InputSenderServer")

var _history_server : NetworkHistoryServer = null
var _synchronization_server : NetworkSynchronizationServer = null
var _simulator_server : SimulatorServer = null

var _missing_inputs_history_size : int = ProjectSettings.get_setting("netfox/input_sender/missing_input_history", 16)
var _input_sender_history_size : int = ProjectSettings.get_setting("netfox/input_sender/history_limit", 64)

# Ticks that we received new input snapshots.
var _ticks_that_has_new_snapshot : Array[int] = []

# Maps InputSender -> InputSenderHistory (inner class, look at the end of this script.)
var _per_input_sender_history : Dictionary = {}

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _synchronization_server: _synchronization_server = NetworkSynchronizationServer
	if not _simulator_server: _simulator_server = SimulatorServer
	
	# Record inputs similiar to rollback so that users can use same methods
	# on their input scripts.
	# For good reasons, We do logic and run InputSender signals on NetworkTime.on_tick
	# This means local players wont have input information for their first tick.
	# Its not really like await processframe but this will only add slight delay that wont have
	# Important effects on the game itself.
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
	#
	# But if we run logic on after_tick_loop, our effect on the game state is lost.
	# Because most setups tends to use state-syncronizer with input-sender.
	# state-syncronzier records on every tick and restores after tick loop.
	# 
	# To make sure our effect isnt lost to this order, we run logic on tick.
	NetworkTime.on_tick.connect(_on_tick)

# Whenever we receive input snapshot, we investigate and fetch _earliest_input tick
# This is later used to iterate over saved snapshots and emit signals.
func _on_received_input_snapshot(snapshot : _Snapshot) -> void:
	if snapshot.is_empty():
		return
	
	if not _ticks_that_has_new_snapshot.has(snapshot.tick):
		_ticks_that_has_new_snapshot.push_back(snapshot.tick)

# After a tick has been run
# Handle new snapshots
# Handle missing inputs.
# Handle local inputs.
#
# Since we are modifying InputSenders before emitting their signals,
# Their input properties will be messed up, this means users inputs wont be
# recorded properly on NetworkTime.after_tick.
# To prevent that, this function records their current state and restores at the
# end of this function.
func _on_tick(_delta : float, tick : int) -> void:
	# First save input-sender states.
	_save_input_sender_states()
	
	_handle_new_snapshots(tick)
	
	# We need to emit missing_input signal for old ticks.
	var missing_tick := tick - _missing_inputs_history_size
	if missing_tick >= 0:
		_handle_missing_tick(missing_tick)
	
	# DANGER
	# We do tick -1 for current local inputs, this is explained on _ready comments.
	_handle_local_inputs(tick - 1)
	
	# Logic is done, restore input-sender states.
	_restore_input_sender_states()
	
	# Now remove older history data that we keep.
	_trim_input_sender_histories(tick)

# Handles new input-sender snapshots.
# This function iterates over _ticks_that_has_new_snapshot. 
# If tick is within range of missing-input-history,
# applies/emits network_input.
# If its not within range,
# it applies/emits late_input.
# Clears _ticks_that_has_new_snapshot after done.
func _handle_new_snapshots(current_tick : int) -> void:
	if _ticks_that_has_new_snapshot.is_empty():
		return
	
	# So ticks are processed in ascending order.
	_ticks_that_has_new_snapshot.sort()
	
	
	for i in _ticks_that_has_new_snapshot:
		
		# This line saves processing because we fetch snapshot once per tick.
		var snapshot := _history_server._get_input_sender_snapshot(i)
		if not snapshot:
			# This situation shouldnt happen anyway.
			continue
		
		# Iterate over input senders and check if there is new input in tick
		for input_sender in _per_input_sender_history.keys():
			if not _is_there_new_input_for_input_sender(input_sender, i, snapshot):
				# No new input, we already processed this one.
				continue
			
			# Did not received before
			# If tick i past the missing_history_size, consider it late.
			input_sender._apply_snapshot_for_self(snapshot)
			if i <= current_tick - _missing_inputs_history_size:
				# Its a late input.
				input_sender.late_input.emit(i)
			else:
				# Its within range, consider it as network input.
				input_sender.network_input.emit(i)
				
				# Notify SimulatorServer about this network_input.
				# Why? Read Simulators and SimulatorServer to learn.
				_simulator_server._notify_input_sender_received_network_input(input_sender, i)
			
			# Set as handled anyway for both situation.
			_set_input_received_for_input_sender(input_sender, i)
	
	_ticks_that_has_new_snapshot.clear()

# Iterates over snapshot for given tick
# Checks _per_input_sender_history for given tick.
# If input_sender did not received anything for this tick
# It assumes input is missing and emits input_missing.
# Call this function after calling _handle_new_snapshots.
# Param for tick must be the value of current_tick - missing_input_history_size.
func _handle_missing_tick(for_tick : int) -> void:
	
	for input_sender in _per_input_sender_history.keys():
		var input_sender_history := _per_input_sender_history[input_sender] as InputSenderHistory
		
		if not input_sender_history.did_receive_for_tick(for_tick):
			# We didnt receive anything for this input sender for this tick.
			# Try to find latest input and emit missing_input.
			
			var latest_tick := _history_server.get_latest_input_sender_for(
				input_sender._input_properties.get_subjects(), for_tick)
			
			if latest_tick >= 0:
				var snapshot := _history_server._get_input_sender_snapshot(latest_tick)
				if snapshot:
					input_sender._apply_snapshot_for_self(snapshot)
				else:
					# If no snapshot, we need to emit signal with -1
					latest_tick = -1
			
			# We may be able to find snapshot or not, emit anyway
			input_sender.missing_input.emit(for_tick, latest_tick)

# Iterates over input-senders and emits local input with latest recorded input available.
# Only does so if input-sender is authoritative peer.

# Duplicated comment from _ready:
#
# "For good reasons, We do logic and run InputSender signals on NetworkTime.on_tick
# This means local players wont have input information for their first tick.
# Its not really like await processframe but this will only add slight delay that wont have
# important effects on the game itself."
func _handle_local_inputs(for_tick : int) -> void:
	
	# Fetch snapshot once before loop to prevent unneccessary fetches.
	var snapshot := _history_server._get_input_sender_snapshot(for_tick)
	if not snapshot:
		# This shouldnt happen anyway.
		return
	
	for input_sender in _per_input_sender_history.keys():
		if input_sender.has_authority_over_input_nodes():
			# Its authoritative player.
			
			# We know that snapshots are recorded for each tick on NetworkTime.after_tick.
			# We can use it, no need to query get_latest_for here.
			input_sender._apply_snapshot_for_self(snapshot)
			input_sender.local_input.emit(for_tick)

# Saves all input-sender input properties.
# This is done before messing with properties.
func _save_input_sender_states() -> void:
	for input_sender in _per_input_sender_history.keys():
		input_sender._save_properties()

# Restores all input-sender input properties.
# This is done after messing with properties.
func _restore_input_sender_states() -> void:
	for input_sender in _per_input_sender_history.keys():
		input_sender._restore_properties()

func _register_input_sender(input_sender : InputSender) -> void:
	_per_input_sender_history[input_sender] = InputSenderHistory.new()

func _deregister_input_sender(input_sender : InputSender) -> void:
	_per_input_sender_history.erase(input_sender)

# Helper that sets input received for param input sender on given tick.
func _set_input_received_for_input_sender(input_sender : InputSender, tick : int) -> void:
	var history : InputSenderHistory = _per_input_sender_history[input_sender] as InputSenderHistory
	if history:
		history.set_as_received_for_tick(tick)

## Check if there is a new input available for given input sender on given tick within matching snapshot.
func _is_there_new_input_for_input_sender(input_sender : InputSender, tick : int, snapshot : _Snapshot) -> bool:
	var history : InputSenderHistory = _per_input_sender_history[input_sender] as InputSenderHistory
	var received_before := history.did_receive_for_tick(tick)
	
	if received_before:
		return false
	
	# We need to check if snapshot has this input senders properties
	if snapshot:
		for property_entry in input_sender._property_entries:
			if snapshot.has_property(property_entry.node, property_entry.property):
				# There is new information available indeed
				return true
	
	# No new information
	return false

# Erases old input sender history data that we dont need anymore.
func _trim_input_sender_histories(current_tick : int) -> void:
	# Since we cant merge older history than input-sender-history
	# we can erase data older than that.
	
	var erase_ticks_older_than_inclusive : int = current_tick - _input_sender_history_size
	
	if erase_ticks_older_than_inclusive > 0:
		for input_sender_history in _per_input_sender_history.values():
			input_sender_history.erase_old_ticks(erase_ticks_older_than_inclusive)

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
