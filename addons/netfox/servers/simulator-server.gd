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

# Node to array of ticks
var _simulated_ticks := {}

# Grouped simulators depending on their authority modes.
# Better readability on code / we only check authority on register.
var _host_simulators : Array[Simulator] = []
var _local_authoritative_simulators : Array[Simulator] = []
var _host_puppet_simulators : Array[Simulator] = []
var _client_puppet_simulators : Array[Simulator] = []

func _init(p_history_server: _NetworkHistoryServer = null, p_synchronization_server: _NetworkSynchronizationServer = null):
	_history_server = p_history_server
	_synchronization_server = p_synchronization_server

func _ready():
	# Ensure dependencies
	if not _history_server: _history_server = NetworkHistoryServer
	if not _synchronization_server: _synchronization_server = NetworkSynchronizationServer

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
	
	_simulated_ticks.erase(simulator)

func _after_tick(tick : int) -> void:
	_handle_host_simulators()
	_handle_host_puppet_simulators()
	_handle_local_authoritative_simulators()
	
	if NetworkTime.tick - _simulation_host_delay_ticks >= 0:
		# History server only records owned simulator state properties.
		_history_server._record_simulator(NetworkTime.tick - _simulation_host_delay_ticks)
		_synchronization_server._synchronize_simulator(NetworkTime.tick - _simulation_host_delay_ticks)
	
	var trim_tick := tick - _simulation_history_size
	if trim_tick >= 0:
		_trim_ticks_simulated(trim_tick)

## 1- host simulator:
## - Advance the simulation with the inputs tick - 1.
##  (input-sender inputs are recorded on after tick).
## - Save the simulator state for current tick.
## - Broadcast it togather with 2.
func _handle_host_simulators() -> void:
	var current_tick := NetworkTime.tick
	
	for simulator in _host_simulators:
		
		# Save input properties before messing them up.
		simulator.listened_input_sender._save_properties()
		
		# Retrieve the input history and apply manually.
		var input_history := _history_server._input_sender_history
		for subject in simulator.listened_input_sender._input_properties.get_subjects():
			input_history.ensure_snapshot(current_tick - 1, subject, true).apply()
		
		var is_fresh := _is_tick_fresh_for(simulator, current_tick)
		simulator._run_simulation(NetworkTime.ticktime, current_tick, is_fresh)
		_history_server._record_individual_simulator(simulator, current_tick)
		_set_tick_simulated_for(simulator, current_tick)
		
		# Restore messed up properties.
		simulator.listened_input_sender._restore_properties()

## 2- local authoritative simulator:
## - We have inputs available locally up to tick -1.
## (input-sender inputs are recorded on after tick).
## - Apply the latest authoritative state received from host. (the truth)
## - Iterate over inputs and reach the current tick - 1.
func _handle_local_authoritative_simulators() -> void:
	var current_tick := NetworkTime.tick
	
	for simulator in _local_authoritative_simulators:
		
		var latest_truth_tick := _history_server.get_latest_simulator_for_snapshot(
			simulator._state_properties.get_subjects(),
			current_tick)
		
		var latest_truth_snapshot := _history_server._get_simulator_snapshot(latest_truth_tick)
		
		# Save inputs before messing input properties.
		simulator.listened_input_sender._save_properties()
		
		if latest_truth_tick < 0 or not latest_truth_snapshot:
			_logger.warning("Couldnt find any truth from host, running simulation for \
			only current tick.")
			
			# Retrieve the input history and apply manually.
			var input_history := _history_server._input_sender_history
			for subject in simulator.listened_input_sender._input_properties.get_subjects():
				input_history.ensure_snapshot(current_tick - 1, subject, true).apply()
			
			var is_fresh := _is_tick_fresh_for(simulator, current_tick)
			simulator._run_simulation(NetworkTime.ticktime, current_tick, is_fresh)
			_history_server._record_individual_simulator(simulator, current_tick)
			_set_tick_simulated_for(simulator, current_tick)
			
			# Restore messed up properties.
			simulator.listened_input_sender._restore_properties()
			continue
		
		simulator._apply_snapshot_for_self(latest_truth_snapshot)
		# Retrieve the input history to apply it manually.
		var input_history := _history_server._input_sender_history
		for i in range(latest_truth_tick + 1, current_tick + 1):
			
			for subject in simulator.listened_input_sender._input_properties.get_subjects():
				var snapshot : _ObjectSnapshot = input_history.ensure_snapshot(i - 1, subject, false)
				if snapshot:
					snapshot.apply()
			
			var is_fresh := _is_tick_fresh_for(simulator, i)
			simulator._run_simulation(NetworkTime.ticktime, i, is_fresh)
			_history_server._record_individual_simulator(simulator, i)
			_set_tick_simulated_for(simulator, i)
		
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
				simulated_tick - 1
			)
		
		var is_fresh := _is_tick_fresh_for(simulator, simulated_tick)
		
		if latest_input_tick == simulated_tick - 1:
			# We have inputs for this tick, run the simulation.
			var input_snapshot := _history_server._get_input_sender_snapshot(latest_input_tick)
			if not input_snapshot:
				_logger.error("No input snapshot found at latest input tick, this shouldnt happen.")
				continue
			
			_logger.trace("Running simulation for %s", [simulator])
			
			
			simulator.listened_input_sender._apply_snapshot_for_self(input_snapshot)
			simulator._run_simulation(NetworkTime.ticktime, simulated_tick, is_fresh)
			
		else:
			# We need to predict this frame.
			_logger.warning("No buffered input found, predicting inputs.")
			
			simulator.listened_input_sender.predict_inputs()
			simulator._run_simulation(NetworkTime.ticktime, simulated_tick, is_fresh)
		
		_set_tick_simulated_for(simulator, simulated_tick)

func _is_tick_fresh_for(node: Node, tick: int) -> bool:
	if not _simulated_ticks.has(node):
		return true
	var ticks := _simulated_ticks.get(node) as Array[int]
	return not ticks.has(tick)

func _set_tick_simulated_for(node: Node, tick: int) -> void:
	if not _simulated_ticks.has(node):
		_simulated_ticks[node] = [tick] as Array[int]
	else:
		_simulated_ticks[node].append(tick)

func _trim_ticks_simulated(beginning: int) -> void:
	for object in _simulated_ticks:
		_simulated_ticks[object] = _simulated_ticks[object]\
			.filter(func(tick): return tick >= beginning)
