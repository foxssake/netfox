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

# Projectiles that are alive.
var _living_projectiles : Array[Node] = []

# Helper to record and restore simulation aware collision-shapes/areas.
var _simulated_collision_recorder : _SimulatedCollisionRecorder = _SimulatedCollisionRecorder.new()

# Fresh registered projectiles.
# Mapped by tick -> array of projectiles (type of Node) that are estimated to be fired on mapped tick.
# See register_projectile method.
var _fresh_registered_projectiles_by_tick : Dictionary[int, Array] = {}

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
	
	_simulated_collision_recorder.initialize(get_tree())

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

## Register a projectile to be stepped by simulation.
## This method should only be called on host.
func register_projectile(projectile : Node, firing_peer_id : int, fired_tick : int) -> void:
	
	var has_step_method := projectile.has_method("step")
	var has_is_alive_method := projectile.has_method("is_alive")
	
	if not has_step_method or not has_is_alive_method:
		_logger.error(
			"Error registering projectile %s : Projectiles must implement step and is_alive methods.",
			[projectile.name]
		)
		return
	
	## Only allow Offline peer and ENet peer to register, because only Enet has rtt statistic functions.
	## Offline is for convenience.
	var enet_peer := multiplayer.multiplayer_peer
	if enet_peer is not ENetMultiplayerPeer and enet_peer is not OfflineMultiplayerPeer:
		_logger.error(
			"Error registering projectile %s : Multiplayer peer is either null or not type of ENet.\n" +
			"Only ENetMultiplayerPeer is supported for now.", [projectile.name]
		)
		return
	
	var firing_peer : ENetPacketPeer = null
	
	if enet_peer is ENetMultiplayerPeer:
		firing_peer = enet_peer.get_peer(firing_peer_id) as ENetPacketPeer
	
	# Allow valid peers only with the exception being server id.
	# OfflinePeer will return id 1 so should be fine.
	if not firing_peer and firing_peer_id != 1:
		_logger.error(
			"Error registering projectile %s: Firing peer #%s is not found on active peers.",
			[projectile.name, firing_peer_id]
		)
		return
	
	var rtt_ms := 0.0
	var half_rtt_sec := 0.0
	var half_rtt_ticks := 0.0
	var estimated_firing_tick := fired_tick - _simulation_host_delay_ticks
	
	# If firing peer is valid get stats and estimate peers simulation tick.
	if firing_peer:
		rtt_ms = firing_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		half_rtt_sec = (rtt_ms * 0.5) / 1000.0
		half_rtt_ticks = half_rtt_sec / NetworkTime.ticktime
		
		# Dont forget that we synchronize current_tick - _simulation_host_delay_ticks
		estimated_firing_tick = fired_tick - roundi(half_rtt_ticks) - _simulation_host_delay_ticks
	
	if estimated_firing_tick < 0:
		_logger.error(
			"Error registering projectile %s: Calculated estimated_firing_tick as negative. Not registering.\n" +
			"half rtt: %s, fired tick: %s, estimated firing tick: %s",
			[projectile.name, half_rtt_sec, fired_tick, estimated_firing_tick]
		)
		return
	
	if estimated_firing_tick < NetworkTime.tick - _simulation_history_size:
		_logger.error(
			"Error registering projectile %s: Calculated estimated_firing_tick is older than history.\n" +
			"Returning without registering. half rtt: %s, fired tick: %s, estimated firing tick: %s",
			[projectile.name, half_rtt_sec, fired_tick, estimated_firing_tick]
		)
		return
	
	_logger.debug(
		"Registered projectile %s with stats:\n" +
		"firing_peer: %s, fired tick: %s, half rtt: %s, estimated firing tick: %s",
		[projectile.name, firing_peer_id, fired_tick, half_rtt_sec, estimated_firing_tick]
	)
	
	var existing_projectile_arr := _fresh_registered_projectiles_by_tick.get_or_add(estimated_firing_tick, []) as Array
	existing_projectile_arr.push_back(projectile)

func _after_tick(tick : int) -> void:
	
	_catch_up_fresh_projectiles(tick)
	
	_handle_host_simulators()
	_handle_host_puppet_simulators()
	_handle_local_authoritative_simulators()
	
	_step_living_projectiles(tick)
	
	if NetworkTime.tick - _simulation_host_delay_ticks >= 0:
		# History server only records owned simulator state properties.
		_history_server._record_simulator(NetworkTime.tick - _simulation_host_delay_ticks)
		_synchronization_server._synchronize_simulator(NetworkTime.tick - _simulation_host_delay_ticks)
		
		_simulated_collision_recorder.record_tick(NetworkTime.tick - _simulation_host_delay_ticks)
	
	# Trim old history that we dont need.
	var trim_tick := tick - _simulation_history_size
	if trim_tick >= 0:
		_trim_ticks_simulated(trim_tick)
		_simulated_collision_recorder.trim_ticks(trim_tick)

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
			_logger.warning(
				"Couldnt find any truth from host.\n" +
				"Running simulation for only current tick."
			)
			
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

# Steps every already-caught-up living projectile by a single tick.
# No need to restore world state for living projectiles.
func _step_living_projectiles(current_tick: int) -> void:
	var simulated_tick := current_tick - _simulation_host_delay_ticks
	
	# Iterate in reverse because we are also removing.
	var i := _living_projectiles.size() - 1
	while i >= 0:
		var projectile : Node = _living_projectiles[i]
		
		if not is_instance_valid(projectile):
			_logger.warning("While stepping living projectiles: projectile at index %s no longer valid, dropping", [i])
			_living_projectiles.remove_at(i)
		else:
			_logger.trace("Stepping living projectile: %s at tick #%s", [projectile.name, simulated_tick])
			projectile.step(NetworkTime.ticktime, simulated_tick)
			
			if not projectile.is_alive():
				_logger.trace("After stepping living projectile: %s projectile died at tick %s",
				[projectile.name, simulated_tick]
				)
				
				_living_projectiles.remove_at(i)
		
		i -= 1

# Steps the freshly registered projectiles up to current_tick - _simulation_host_delay_ticks (not included).
func _catch_up_fresh_projectiles(current_tick: int) -> void:
	if _fresh_registered_projectiles_by_tick.is_empty():
		return
	
	var simulated_tick := current_tick - _simulation_host_delay_ticks
	var oldest_tick : int = _fresh_registered_projectiles_by_tick.keys().min()
	
	# Ensure oldest tick is not older than our history window.
	oldest_tick = maxi(oldest_tick, current_tick - _simulation_history_size)
	
	_logger.trace(
		"Catching up fresh projectiles: oldest_tick=%s, simulated_tick=%s, pending_ticks=%s",
		[oldest_tick, simulated_tick, _fresh_registered_projectiles_by_tick.keys()]
	)
	
	# Temp array to hold projectiles.
	var fresh_projectiles : Array[Node] = []
	
	# We need to capture current state of collision aware nodes. Because we will mess with their
	# states during our operation. At the end of the operation we will restore to this state snapshot.
	var current_collision_state_snapshot_dict := _simulated_collision_recorder.capture_current_state()
	
	for tick in range(oldest_tick, simulated_tick):
		# Restore simulation aware collision nodes.
		_simulated_collision_recorder.restore_tick(tick)
		
		# Get projectiles registered at this tick and add it our fresh_projectiles array.
		var registered_projectiles_arr_at_tick := _fresh_registered_projectiles_by_tick.get(tick, []) as Array
		if not registered_projectiles_arr_at_tick.is_empty():
			_logger.trace(
				"Tick %s: %s registered projectiles are joining the projectile catch up phase: %s",
				[tick, registered_projectiles_arr_at_tick.size(),
				registered_projectiles_arr_at_tick.map(
					func(p): return _get_projectile_debug_name(p))
				]
			)
			
			fresh_projectiles.append_array(registered_projectiles_arr_at_tick)
			_fresh_registered_projectiles_by_tick.erase(tick)
		
		# While iterating over ticks, step every fresh projectile we have.
		var i := fresh_projectiles.size() - 1
		while i >= 0:
			
			var projectile : Node = fresh_projectiles[i]
			
			if is_instance_valid(projectile):
				projectile.step(NetworkTime.ticktime, tick)
				_logger.trace("Projectile %s running catch up step at tick: #%s", [projectile.name, tick])
				# Erase from our list if projectile is not alive anymore.
				if not projectile.is_alive():
					_logger.trace("Projectile %s is not alive, erasing at tick: #%s", [projectile.name, tick])
					fresh_projectiles.remove_at(i)
			else:
				_logger.trace("During projectile catch up, projectile at index %s no longer valid, dropping", [i])
				fresh_projectiles.remove_at(i)
			
			i -= 1
	
	# Anything registered for tick exact simulated_tick had no history to replay.
	# They join living unstepped and gets its first step together with _step_living_projectiles.
	var registered_at_simulated_tick := _fresh_registered_projectiles_by_tick.get(simulated_tick, []) as Array
	if not registered_at_simulated_tick.is_empty():
		_logger.trace(
			"At Simulated tick #%s, %s projectile(s) joining to living projectiles without catch up.\n" + 
			"They will be stepped together with living projectiles on this tick. Projectile names %s",
			[simulated_tick, registered_at_simulated_tick.size(),
			registered_at_simulated_tick.map(
				func(p): return _get_projectile_debug_name(p))
			]
		)
		
		fresh_projectiles.append_array(registered_at_simulated_tick)
		_fresh_registered_projectiles_by_tick.erase(simulated_tick)
	
	if not fresh_projectiles.is_empty():
		_logger.trace(
			"Projectile catch up is over: %s projectile(s) promoted to living: %s",
			[fresh_projectiles.size(), fresh_projectiles.map(
				func(p): return _get_projectile_debug_name(p))
			]
		)
	
	# Append our living projectiles list, they are part of the current simulation at this point,
	# and they will be handled with function _step_living_projectiles.
	_living_projectiles.append_array(fresh_projectiles)
	
	# Since we changed states of simulation aware collision nodes by calling
	# _simulated_collision_recorder.restore_tick, now we should restore them to current state which
	# we recorded before doing this operation.
	_simulated_collision_recorder.restore_snapshot(current_collision_state_snapshot_dict)

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

# Helper to get projectile debug name.
func _get_projectile_debug_name(p) -> String:
	return p.name if is_instance_valid(p) else "<invalid>"
