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
## - Save the simulator state for current tick.
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
## 4 can be simply achieved with NetworkHistoryServer._restore_simulator

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
	pass


# Register a simulator node.
# Will check for authority over inputs and categorize by it.
# Its Simulator's responsibility to only register if input-sender is configured.
func _register_simulator(simulator : Simulator) -> void:
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
func _deregister_simulator(simulator : Simulator) -> void:
	_host_simulators.erase(simulator)
	_host_puppet_simulators.erase(simulator)
	_local_authoritative_simulators.erase(simulator)
	_client_puppet_simulators.erase(simulator)

func _init(p_history_server: _NetworkHistoryServer = null, p_synchronization_server: _NetworkSynchronizationServer = null):
	_history_server = p_history_server
	_synchronization_server = p_synchronization_server
