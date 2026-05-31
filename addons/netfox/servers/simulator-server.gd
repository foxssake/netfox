extends Node
class_name _SimulatorServer

# @public class

## Handles [Simulator] related operations.

## TODO: We should find a better name for Simulator word.
##
## [Before reading this server, please read InputSender, InputSenderServer, Simulator.]
##
##
## Insight:
## SimulatorServer has to know details about each simulators input-senders.
## Inputs might not always arrive at correct order.
## Inputs might not always arrive.
## Since iterating over every snapshot and check for them is already done by
## InputSenderServer, we will expose a function for InputSenderServer to notify
## us with the input state of simulators.
## SimulatorServer will not consider late or missing inputs to derive simulation.

var _history_server : _NetworkHistoryServer = null
var _synchronization_server : _NetworkSynchronizationServer = null

var _simulation_history_size : int = ProjectSettings.get_setting("netfox/simulator/history_limit", 64)

# Simulators that has input authority.
# These simulators would be your typical local players.
# If this is host, these simulators also owns state.
# But that doesnt need an extra category.
# For this category, we accept the truth from latest known state
# and apply local inputs until we reach current tick.
var _authoritative_simulators : Array[Simulator] = []

# Simulators that has no input authority.
# These simulators belong to remote players.
#
# On host:
# These simulators also owns state.
# We run simulation one tick per received network_input.
#
# On other players:
# These simulators are not doing any simulation at all.
# These simulators are accepting latest truth and applying that state.
var _puppet_simulators : Array[Simulator] = []

# Maps InputSender to Simulator.
# We keep this to easily reach in reverse fashion when we need it.
var _input_sender_to_simulator : Dictionary = {}

# Maps simulator to simulator-input-history (inner class at the end of the file)
# SimulatorInputHistories are buffered on _notify_input_sender_received_network_input,
# SimulatorInputHistories are consumed on _after_tick_loop.
var _simulator_to_simulator_input_history : Dictionary = {}

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _synchronization_server: _synchronization_server = NetworkSynchronizationServer
	
	# Just like rollback, record and synchronize after tick.
	# TODO if we find out that physics dont work like this, find better timing.
	NetworkTime.after_tick.connect(func(_dt, tick):
		_history_server._record_simulator(tick)
		_synchronization_server._synchronize_simulator(tick)
	)
	
	# We do our simulating logic after tick loop, similiar to rollback in general.
	# TODO if we find out that physics dont work like this, find better timing.
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

# Do simulating logic depending on authorities.
func _after_tick_loop() -> void:
	
	_handle_authoritatives()
	_handle_puppets()
	
	# Since we consumed, we can now clear this.
	_simulator_to_simulator_input_history.clear()

func _handle_authoritatives() -> void:
	var current_tick := NetworkTime.tick
	
	if is_multiplayer_authority():
		# This is host.
		# On host we need to advance authoritative player with our local inputs.
		# In another words - this is a host playing locally.
		for simulator in _authoritative_simulators:
			
			# DANGER we are doing current_tick -1 because input-senders are recorded
			# on after-tick.
			var input_snapshot := _history_server._get_input_sender_snapshot(current_tick -1)
			
			if not input_snapshot:
				# no input snapshot for some reason, this shouldnt really happen.
				continue
			
			var input_sender := simulator.listened_input_sender
			# Save current properties so that we dont mess with input recording.
			input_sender._save_properties()
			
			input_sender._apply_snapshot_for_self(input_snapshot)
			# TODO do we use ticktime for delta value???
			simulator._run_simulation(NetworkTime.ticktime, current_tick)
			
			# Restore input_sender properties after messing with inputs
			input_sender._restore_properties()
	else:
		# This is local authoritative player.
		# On local players we need to first accept latest received truth from host.
		# Then simulate our local inputs to reach current state.
		
		for simulator in _authoritative_simulators:
			
			var latest_state_tick := _history_server.get_latest_simulator_for(
				simulator._state_properties.get_subjects(), current_tick)
			
			if latest_state_tick >= 0:
				var latest_state_snapshot := _history_server._get_simulator_snapshot(latest_state_tick)
				
				if latest_state_snapshot:
					simulator._apply_snapshot_for_self(latest_state_snapshot)
			
			# Whether we found latest snapshot or not, we need to iterate over our local inputs now.
			
			var simulation_start_tick := latest_state_tick
			
			# Dont let it past the history size.
			if simulation_start_tick < current_tick - _simulation_history_size:
				simulation_start_tick = current_tick - _simulation_history_size
			
			# Dont let it become negative.
			if simulation_start_tick < 0:
				simulation_start_tick = 0
			
			# DANGER since we only have inputs available up to current_tick -1
			# We will stop at current_tick - 1 INCLUSIVE
			# Why -1 ? Read InputSenderServer.
			
			# Record input_sender state before messing with inputs.
			simulator.listened_input_sender._save_properties()
			
			for i in range(simulation_start_tick, current_tick):
				var input_snapshot := _history_server._get_input_sender_snapshot(i)
				
				# We should have input snapshot available for ourselves anyway...
				if input_snapshot:
					simulator.listened_input_sender._apply_snapshot_for_self(input_snapshot)
					# TODO do we use ticktime for delta value???
					simulator._run_simulation(NetworkTime.ticktime, i)
			
			# Restore input_sender state after messing with inputs.
			simulator.listened_input_sender._restore_properties()

func _handle_puppets() -> void:
	var current_tick := NetworkTime.tick
	
	if is_multiplayer_authority():
		# This is host,
		# On host we derive the simulation forward with new network_inputs.
		
		for simulator in _puppet_simulators:
			
			# Check if we have new input for this simulator
			var simulator_input_history := _simulator_to_simulator_input_history.get(simulator) as SimulatorInputHistory
			
			if not simulator_input_history:
				continue
			
			var ticks_with_new_inputs : Array[int] = simulator_input_history.get_ticks_with_new_inputs()
			
			if ticks_with_new_inputs.is_empty():
				continue
			
			# We dont need to record/restore input_sender state as we dont own input.
			
			for new_input_tick in ticks_with_new_inputs:
				var input_snapshot := _history_server._get_input_sender_snapshot(new_input_tick)
				
				if not input_snapshot:
					# This shouldnt happen anyway.
					continue
				
				simulator.listened_input_sender._apply_snapshot_for_self(input_snapshot)
				# TODO do we use ticktime for delta value???
				simulator._run_simulation(NetworkTime.ticktime, new_input_tick)
	else:
		# This is not host
		# We only accept the true state which is broadcasted to us.
		
		for simulator in _puppet_simulators:
			
			var latest_state_snapshot_tick := _history_server.get_latest_simulator_for(
				simulator._state_properties.get_subjects(), current_tick)
			
			if latest_state_snapshot_tick >= 0:
				var state_snapshot := _history_server._get_simulator_snapshot(latest_state_snapshot_tick)
				
				if state_snapshot:
					simulator._apply_snapshot_for_self(state_snapshot)

## InputSenderServer will call this function to notify that param input_sender
## received a new network_input on param on_tick. This network_input must also be
## within range of missing_input_history size.
## (See projectSettings netfox/input-sender/missing-input-history)
## (Also read InputSenderServer)
func _notify_input_sender_received_network_input(input_sender : InputSender, on_tick : int) -> void:
	var matching_simulator := _input_sender_to_simulator.get(input_sender) as Simulator
	
	if not matching_simulator:
		return
	
	var simulator_input_history := _simulator_to_simulator_input_history.get(matching_simulator) as SimulatorInputHistory
	
	if not simulator_input_history:
		simulator_input_history = SimulatorInputHistory.new()
		_simulator_to_simulator_input_history[matching_simulator] = simulator_input_history
	
	simulator_input_history.push_back_new_input_tick(on_tick)

# Register a simulator node.
# Will check for authority over inputs and categorize by it.
func _register_simulator(simulator : Simulator) -> void:
	if simulator.has_authority_over_inputs():
		_authoritative_simulators.push_back(simulator)
	else:
		_puppet_simulators.push_back(simulator)
	
	_input_sender_to_simulator[simulator.listened_input_sender] = simulator

# Deregister a simulator node.
func _deregister_simulator(simulator : Simulator) -> void:
	_puppet_simulators.erase(simulator)
	_authoritative_simulators.erase(simulator)
	
	_input_sender_to_simulator.erase(_input_sender_to_simulator.find_key(simulator))

func _init(p_history_server: _NetworkHistoryServer = null, p_synchronization_server: _NetworkSynchronizationServer = null):
	_history_server = p_history_server
	_synchronization_server = p_synchronization_server

## Inner class to keep Simulator related input ticks organized.
## Whenever InputSenderServer notifies us about input-sender-recived-network-input.
## If we have simulator for that given input-sender
## We will store that tick with the help of this class.
## Later on we will consume these stored ticks to run simulation.
class SimulatorInputHistory extends RefCounted:
	
	var _ticks_with_new_inputs : Array[int] = []
	
	func push_back_new_input_tick(new_input_tick : int) -> void:
		if not _ticks_with_new_inputs.has(new_input_tick):
			_ticks_with_new_inputs.push_back(new_input_tick)
	
	func get_ticks_with_new_inputs() -> Array[int]:
		return _ticks_with_new_inputs
