extends Node
class_name _SimulatorServer

# @public class

## Handles [Simulator] related operations.

## TODO: We should find a better name for Simulator word.
##
## [Before reading this server, please read InputSender, InputSenderServer, Simulator.]

## Insight
##
##
## Depending on simulator authority there are 4 options we can operate on:
##
## 1- We have authority over both simulator input/state = host simulator
## 2- We have authority over input but not state = local authoritative simulator
## 3- We have authority over state but not input = host puppet
## 4- We dont have any authority over input/state = client puppet
##
## 1- host simulator:
## - Advance the simulation with the inputs tick - 1.
##  (input-sender inputs are recorded on after tick).
## - Save the simulator state for current tick as invidiual fashion.
## - Broadcast it togather with 2.
##
## 2- local authoritative simulator:
## - We have inputs available locally up to tick -1.
## (input-sender inputs are recorded on after tick).
## - Apply the latest authoritative state received from host. (the truth)
## - Iterate over inputs and reach the current tick - 1.
##
## 3- host puppet.
## - If we dont have inputs buffered yet, dont run the simulation, simply skip.
## - If we have inputs buffered, run the simulation with indexed inputs for 1 simulation tick.
## - Record the simulator state for given simulation tick.
## - Broadcast them.
##
## 4- client puppet.
## - Apply the latest authoritative state received from host. (the truth)
##
##
## By restoring to latest state we already handle 4.
## We dont need to keep history of non-host simulators.


var _history_server : _NetworkHistoryServer = null
var _synchronization_server : _NetworkSynchronizationServer = null
var _logger := NetfoxLogger._for_netfox("SimulatorServer")

# History size for simulation.
var _simulation_history_size : int = ProjectSettings.get_setting("netfox/simulator/history_limit", 64)

# Host side buffering/delay tick count for simulation.
var _simulation_host_delay_ticks : int = ProjectSettings.get_setting("netfox/simulator/host_delay_ticks", 8)

# Grouped simulators depending on their authority modes.
# Better readability on code / we only check authority on register.
var _host_simulators : Array[Simulator] = []
var _local_authoritative_simulators : Array[Simulator] = []
var _host_puppet_simulators : Array[Simulator] = []
var _client_puppet_simulators : Array[Simulator] = []

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _synchronization_server: _synchronization_server = NetworkSynchronizationServer
	
	# Just like rollback, record and synchronize after tick.
	# We only need to record _host_puppet_simulators and _host_simulators.
	# _host_simulators are saved individually.
#	NetworkTime.after_tick.connect(func(_dt, tick):
#
#		for simulator in _host_simulators:
#			_history_server.ignore(simulator)
#
#		for simulator in _local_authoritative_simulators:
#			_history_server.ignore(simulator)
#
#		for simulator in _client_puppet_simulators:
#			_history_server.ignore(simulator)
#
#		if tick - _simulation_host_delay_ticks >= 0:
#			_history_server._record_simulator(tick - _simulation_host_delay_ticks)
#			_synchronization_server._synchronize_simulator(tick - _simulation_host_delay_ticks)
#
#		_history_server.flush_ignores()
#	)
	
	# We do our simulating logic after tick loop, similiar to rollback in general.
	# TODO if we find out that physics dont work like this, find better timing.
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _after_tick_loop() -> void:
	_handle_host_simulators()
	_handle_host_puppet_simulators()
	_handle_local_authoritative_simulators()
	
	# We only need to save host_simulators and _host_puppet_simulators.
	for simulator in _local_authoritative_simulators:
		_history_server.ignore(simulator)
	
	for simulator in _client_puppet_simulators:
		_history_server.ignore(simulator)
	
	if  NetworkTime.tick - _simulation_host_delay_ticks >= 0:
		_history_server._record_simulator(NetworkTime.tick - _simulation_host_delay_ticks)
		_synchronization_server._synchronize_simulator(NetworkTime.tick - _simulation_host_delay_ticks)
	
	_history_server.flush_ignores()
	_history_server._restore_simulator(NetworkTime.tick)

## 1- host simulator:
## - Advance the simulation with the inputs tick - 1.
##  (input-sender inputs are recorded on after tick).
## - Save the simulator state for current tick.
## - Broadcast it togather with 2.
func _handle_host_simulators() -> void:
	var current_tick := NetworkTime.tick
	
	for simulator in _host_simulators:
		
		var input_snapshot := _history_server._get_input_sender_snapshot(current_tick - 1)
		
		if not input_snapshot:
			_logger.error("Host simulator: %s should have had inputs available for tick %s\
			skipping simulation.", [simulator, current_tick])
			
			continue
		
		# Save input properties before messing them up.
		simulator.listened_input_sender._save_properties()
		
		simulator.listened_input_sender._apply_snapshot_for_self(input_snapshot)
		simulator._run_simulation(NetworkTime.ticktime, current_tick)
		
		# Restore messed up properties.
		simulator.listened_input_sender._restore_properties()

## 2- local authoritative simulator:
## - We have inputs available locally up to tick -1.
## (input-sender inputs are recorded on after tick).
## - Apply the latest authoritative state received from host. (the truth)
## - Iterate over inputs and reach the current tick - 1.
##
## Latest authoritatiev state is already applied for us before calling this function.
## Iteratre over inputs and reach the current tick - 1.
func _handle_local_authoritative_simulators() -> void:
	var current_tick := NetworkTime.tick
	
	for simulator in _local_authoritative_simulators:
		
		# Save input properties before messing them up.
		simulator.listened_input_sender._save_properties()
		
		var latest_truth_tick := _history_server.get_latest_simulator_for(simulator.state_properties, current_tick)
		
		for i in range(latest_truth_tick, current_tick):
			
			var input_snapshot := _history_server._get_simulator_snapshot(i)
			
			if not input_snapshot:
				_logger.error("Host simulator: %s should have had inputs available for tick %s\
				skipping simulation.", [simulator, current_tick])
				
				continue
			
			simulator.listened_input_sender._apply_snapshot_for_self(input_snapshot)
			simulator._run_simulation(NetworkTime.ticktime, current_tick)
			_history_server._record_individual_simulator(simulator, current_tick)
		
		# Restore messed up properties.
		simulator.listened_input_sender._restore_properties()

## 3- host puppet.
## - If we dont have inputs buffered yet, dont run the simulation, simply skip.
## - If we have inputs buffered, run the simulation with indexed inputs for 1 simulation tick.
## - Record the simulator state for given simulation tick.
## - Broadcast them.
func _handle_host_puppet_simulators() -> void:
	var current_tick := NetworkTime.tick
	
	var simulated_tick := current_tick - _simulation_host_delay_ticks
	
	for simulator in _host_puppet_simulators:
		
		var latest_input_tick := _history_server.get_latest_input_sender_for(
				simulator.listened_input_sender._input_properties.get_subjects(),
				simulated_tick
			)
		
		if latest_input_tick == simulated_tick:
			# We have inputs for this tick, run the simulation.
			var input_snapshot := _history_server._get_input_sender_snapshot(latest_input_tick)
			if not input_snapshot:
				_logger.error("No input snapshot found at latest input tick, this shouldnt happen.")
				continue
			
			_logger.trace("Running simulation for %s", [simulator])
			simulator.listened_input_sender._apply_snapshot_for_self(input_snapshot)
			simulator._run_simulation(NetworkTime.ticktime, simulated_tick)
		else:
			# We need to predict this frame.
			_logger.warning("No buffered input found, predicting inputs.")
			
			simulator.listened_input_sender.predict_inputs()
			simulator._run_simulation(NetworkTime.ticktime, simulated_tick)

# Register a simulator node.
# Will check for authority over inputs and categorize by it.
# Its Simulator's responsibility to only register if input-sender is configured.
func register_simulator(simulator : Simulator) -> void:
	if simulator.is_multiplayer_authority():
		if simulator.listened_input_sender.has_authority_over_input_nodes():
			_host_simulators.push_back(simulator)
		else:
			_host_puppet_simulators.push_back(simulator)
	else:
		if simulator.listened_input_sender.has_authority_over_input_nodes():
			_local_authoritative_simulators.push_back(simulator)
		else:
			_client_puppet_simulators.push_back(simulator)

# Deregister a simulator node.
func deregister_simulator(simulator : Simulator) -> void:
	_host_simulators.erase(simulator)
	_host_puppet_simulators.erase(simulator)
	_local_authoritative_simulators.erase(simulator)
	_client_puppet_simulators.erase(simulator)

func _init(p_history_server: _NetworkHistoryServer = null, p_synchronization_server: _NetworkSynchronizationServer = null):
	_history_server = p_history_server
	_synchronization_server = p_synchronization_server
