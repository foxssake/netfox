extends Node
class_name _SimulatorServer

# @public class

## Handles [Simulator] related operations.

## TODO: We should find a better name for Simulator word.
##
## [Before reading this server, please read InputSender, InputSenderServer, Simulator.]

## Insight
##
## Time model: the host's tick is the truth. The host simulates everyone, its
## own player and remote players, at its current tick. Clients stamp their
## inputs ahead of their own tick (input lead), so the inputs arrive before the
## host needs them. Clients predict their own player up to tick + input lead.
## See [_SimulatorTimeTracker].
##
## Simulating a tick works the same way as rollback: simulating tick T applies
## the inputs of tick T, calls _simulated_tick(delta, T, is_fresh), and the
## resulting state is recorded as the state of tick T + 1. Inputs of tick T
## are recorded on after_tick, before SimulatorServer runs, so they're always
## there for our own inputs. Example for the host, at tick 100:
##
##   after_tick           | input of tick 100 is recorded
##   SimulatorServer      | inputs of 100 applied, _simulated_tick(delta, 100)
##                        | state recorded and sent as tick 101
##   after_tick_loop      | state of tick 101 is shown
##
## This also puts Simulators in the same tick numbers as StateSynchronizers,
## which record state after a tick as tick + 1 too.
##
## Depending on simulator authority there are 4 options we can operate on:
##
## 1- We have authority over both simulator input/state = host simulator
## 2- We have authority over input but not state = local authoritative simulator
## 3- We have authority over state but not input = host puppet
## 4- We dont have any authority over input/state = client puppet
##
## 1- host simulator:
## - Simulate the current tick with its inputs.
##  (input-sender inputs are recorded on after tick).
## - Save the resulting state as tick + 1, as invidiual fashion.
## - Broadcast it togather with 2.
##
## 2- local authoritative simulator:
## - We have inputs available locally up to tick + input lead.
## (input-sender inputs are recorded on after tick).
## - Apply the latest authoritative state received from host. (the truth)
## - Simulate every tick from the truth up to tick + input lead, which results
## in the state of tick + input lead + 1.
##
## 3- host puppet.
## - Simulate the current tick with its inputs.
## Clients stamp inputs ahead, so they are usually here already.
## - If inputs are missing, predict them, see InputSender.
## - Save the resulting state as tick + 1.
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

# How many ticks of the past we keep for simulation, e.g. recorded collision
# shapes, and how far back projectiles can be caught up.
# The history buffers also have room for the future on top of this, see
# _SimulatorTimeTracker.get_future_history_ticks().
var _simulation_history_size : int = ProjectSettings.get_setting("netfox/simulator/history_limit", 64)

# Maximum view delay accepted from clients, in ticks. Limits how far into the
# past a client can rewind when firing, see register_projectile.
var _max_view_delay_ticks : int = ProjectSettings.get_setting("netfox/simulator/max_view_delay_ticks", 30)

# Node -> latest tick simulated for it, see _is_tick_fresh_for.
var _latest_simulated_ticks : Dictionary = {}

# Projectiles that are alive.
var _living_projectiles : Array[Node] = []

# Helper to record and restore simulation aware collision-shapes/areas.
var _simulated_collision_recorder : _SimulatedCollisionRecorder = _SimulatedCollisionRecorder.new()

# Helper to track how each client's time relates to the host's: input lead and
# view delay. See _SimulatorTimeTracker.
var _time_tracker : _SimulatorTimeTracker = _SimulatorTimeTracker.new()

# Fresh registered projectiles.
# Mapped by tick (int) -> Array of projectiles (Node) that are estimated to be fired on mapped tick.
# See register_projectile method.
var _fresh_registered_projectiles_by_tick : Dictionary = {}

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
	NetworkTime.after_sync.connect(_reset_simulated_ticks)
	# View delay samples are stamped ahead like inputs, so they get the same
	# room for the future as the Simulator history buffers.
	_time_tracker.initialize(self, NetworkCommandServer, _synchronization_server,
		_simulation_history_size + _SimulatorTimeTracker.get_future_history_ticks())

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

	_latest_simulated_ticks.erase(simulator)

## Register a projectile to be stepped by simulation.
## This method should only be called on host.
## [br][br]
## [param fired_tick] is the tick of the fire input, e.g. the tick passed to
## [code]_simulated_tick[/code] when the fire input is applied, or the tick
## given by [signal InputSender.input_applied].
## [br][br]
## The projectile is caught up from the tick of the host's simulation that the
## firing peer was seeing at [param fired_tick], see [_SimulatorTimeTracker]. The
## rewind is limited by [code]netfox/simulator/max_view_delay_ticks[/code].
## [br][br]
## Projectiles are stepped after Simulators, so stepping a projectile for tick
## T checks it against the world after this tick's movement, the state of
## T + 1. The same is true while catching up.
func register_projectile(projectile : Node, firing_peer_id : int, fired_tick : int) -> void:

	var has_step_method := projectile.has_method("step")
	var has_is_alive_method := projectile.has_method("is_alive")

	if not has_step_method or not has_is_alive_method:
		_logger.error(
			"Error registering projectile %s : Projectiles must implement step and is_alive methods.",
			[projectile.name]
		)
		return

	var view_delay := _get_view_delay_for(firing_peer_id, fired_tick)

	# The firing peer saw the state of tick fired_tick - view_delay. Stepping
	# tick T checks against the state of T + 1, so start one tick earlier: the
	# first step then checks against exactly what the firing peer saw.
	# Example: the peer saw the state of 97, so the first step is for tick 96,
	# and checks against the state of 97.
	var estimated_firing_tick := fired_tick - view_delay - 1

	# Without a view delay sample, the fire input's tick can be in the future
	# for a client, see _get_view_delay_for. Never start later than now.
	estimated_firing_tick = mini(estimated_firing_tick, NetworkTime.tick)

	if estimated_firing_tick < 0:
		_logger.error(
			"Error registering projectile %s: Calculated estimated_firing_tick as negative. Not registering.\n" +
			"view delay: %s, fired tick: %s, estimated firing tick: %s",
			[projectile.name, view_delay, fired_tick, estimated_firing_tick]
		)
		return

	if estimated_firing_tick < NetworkTime.tick - _simulation_history_size:
		_logger.error(
			"Error registering projectile %s: Calculated estimated_firing_tick is older than history.\n" +
			"Returning without registering. view delay: %s, fired tick: %s, estimated firing tick: %s",
			[projectile.name, view_delay, fired_tick, estimated_firing_tick]
		)
		return

	_logger.debug(
		"Registered projectile %s with stats:\n" +
		"firing_peer: %s, fired tick: %s, view delay: %s, estimated firing tick: %s",
		[projectile.name, firing_peer_id, fired_tick, view_delay, estimated_firing_tick]
	)

	if not _fresh_registered_projectiles_by_tick.has(estimated_firing_tick):
		_fresh_registered_projectiles_by_tick[estimated_firing_tick] = []
	var existing_projectile_arr := _fresh_registered_projectiles_by_tick[estimated_firing_tick] as Array
	existing_projectile_arr.push_back(projectile)

# Returns how many ticks behind the given peer saw the host's simulation at
# the given tick of the peer.
func _get_view_delay_for(peer: int, tick: int) -> int:
	# The host sees everyone at its current tick, nothing to rewind.
	# This also covers offline play.
	if peer == multiplayer.get_unique_id():
		return 0

	var view_delay := _time_tracker.get_view_delay(peer, tick, -1)
	if view_delay < 0:
		# No sample for this tick, e.g. the peer just connected. Without a
		# sample, don't rewind at all.
		_logger.debug("No view delay from peer #%s @%d, not rewinding", [peer, tick])
		return 0

	# The view delay is reported by the client, so don't trust it blindly.
	# It can't rewind further than max_view_delay_ticks.
	return clampi(view_delay, 0, maxi(0, _max_view_delay_ticks))

## Returns how many ticks ahead this peer stamps its inputs, see
## [_SimulatorTimeTracker]. Always 0 on the host.
func get_input_lead_ticks() -> int:
	return _time_tracker.get_input_lead()

## Returns the maximum input lead in ticks, see
## [code]netfox/simulator/max_input_lead[/code].
func get_max_input_lead_ticks() -> int:
	return _time_tracker.get_max_input_lead_ticks()

## Returns the maximum view delay in ticks, see
## [code]netfox/simulator/max_view_delay_ticks[/code]. The host never rewinds
## further than this when registering projectiles, see
## [method register_projectile].
func get_max_view_delay_ticks() -> int:
	return maxi(0, _max_view_delay_ticks)

## Client side: returns the view delay this peer reports to the host, in ticks,
## or -1 if no simulator state has arrived yet.
## [br][br]
## The input lead is included, so this is how far the host rewinds when this
## peer fires, see [_SimulatorTimeTracker].
func get_view_delay_ticks() -> int:
	return _time_tracker.get_reported_view_delay()

## Host side: returns the newest view delay reported by [param peer], in ticks,
## or -1 if it hasn't reported yet.
## [br][br]
## Not clamped to [method get_max_view_delay_ticks].
func get_view_delay_ticks_for(peer: int) -> int:
	return _time_tracker.get_latest_view_delay(peer)

# Returns how many ticks ahead we stamp our inputs. Always 0 on the host.
# Used by InputSenderServer and NetworkTime internally.
func _get_input_lead() -> int:
	return _time_tracker.get_input_lead()

# Returns whether an input stamped with the given tick is accepted now. Inputs
# stamped too far ahead are dropped, see _SimulatorTimeTracker.
# Used by NetworkSynchronizationServer internally.
func _is_input_tick_accepted(stamped_tick: int) -> bool:
	return _time_tracker.is_input_tick_accepted(stamped_tick, NetworkTime.tick)

func _after_tick(tick : int) -> void:

	_catch_up_fresh_projectiles(tick)

	_handle_host_simulators(tick)
	_handle_host_puppet_simulators(tick)
	_handle_local_authoritative_simulators(tick)

	_step_living_projectiles(tick)

	# Everything was simulated for the current tick, the result is the state of
	# the next tick. So everything is recorded and sent under tick + 1.
	# History server only records owned simulator state properties.
	_history_server._record_simulator(tick + 1)
	_synchronization_server._synchronize_simulator(tick + 1)

	# Collision shapes after this tick's movement, see _catch_up_fresh_projectiles.
	_simulated_collision_recorder.record_tick(tick + 1)

	# Trim old history that we dont need.
	var trim_tick := tick - _simulation_history_size
	if trim_tick >= 0:
		_simulated_collision_recorder.trim_ticks(trim_tick)

## 1- host simulator:
## - Simulate the current tick with its inputs.
##  (input-sender inputs are recorded on after tick).
## - Save the resulting state as tick + 1.
## - Broadcast it togather with 2.
func _handle_host_simulators(current_tick: int) -> void:
	for simulator in _host_simulators:

		var input_subjects := simulator.listened_input_sender._input_properties.get_subjects()
		var state_subjects := simulator._state_properties.get_subjects()

		# Save input properties before messing them up.
		simulator.listened_input_sender._save_properties()

		# Apply inputs of this tick.
		_history_server._restore_input_sender_subjects(input_subjects, current_tick)

		var is_fresh := _is_tick_fresh_for(simulator, current_tick)
		simulator._run_simulation(NetworkTime.ticktime, current_tick, is_fresh)
		_history_server._record_simulator_subjects(state_subjects, current_tick + 1)
		_set_tick_simulated_for(simulator, current_tick)

		# Restore messed up properties.
		simulator.listened_input_sender._restore_properties()

## 2- local authoritative simulator:
## - We have inputs available locally up to tick + input lead.
## (input-sender inputs are recorded on after tick).
## - Apply the latest authoritative state received from host. (the truth)
## - Simulate every tick from the truth up to tick + input lead, which results
## in the state of tick + input lead + 1.
##
## Example, with a lead of 5 at tick 100, and the latest truth for tick 97:
## restore the state of 97, then simulate ticks 97 .. 105 with their inputs.
## The result is the state of tick 106, which is shown.
func _handle_local_authoritative_simulators(current_tick: int) -> void:
	# Our inputs are stamped this far ahead, so we simulate this far ahead too.
	# This is the newest input we have, recorded on this tick's after_tick.
	var predicted_tick := current_tick + _get_input_lead()

	for simulator in _local_authoritative_simulators:

		var state_subjects := simulator._state_properties.get_subjects()

		# The host sends the state after its tick T as T + 1, so the truth can be
		# a tick ahead of us. Nothing newer than our prediction can be truth.
		var latest_truth_tick := _history_server.get_latest_simulator_for_snapshot(
			state_subjects,
			predicted_tick + 1)

		var latest_truth_snapshot := _history_server._get_simulator_snapshot(latest_truth_tick)

		# Save inputs before messing input properties.
		simulator.listened_input_sender._save_properties()

		if latest_truth_tick < 0 or not latest_truth_snapshot:
			_logger.warning(
				"Couldnt find any truth from host.\n" +
				"Running simulation for only current tick."
			)

			# Apply our newest inputs.
			_apply_input_at(simulator.listened_input_sender, predicted_tick)

			var is_fresh := _is_tick_fresh_for(simulator, predicted_tick)
			simulator._run_simulation(NetworkTime.ticktime, predicted_tick, is_fresh)
			_history_server._record_simulator_subjects(state_subjects, predicted_tick + 1)
			_set_tick_simulated_for(simulator, predicted_tick)

			# Restore messed up properties.
			simulator.listened_input_sender._restore_properties()
			continue

		# Apply truth from history, which has diffs merged into full state.
		_history_server._restore_simulator_subjects(state_subjects, latest_truth_tick)

		for i in range(latest_truth_tick, predicted_tick + 1):
			# Apply inputs of this tick. If there's no input recorded for it,
			# the latest input before it is applied. Right after spawning, the
			# truth can be older than our first input, then the default input
			# is applied, see _apply_input_at().
			_apply_input_at(simulator.listened_input_sender, i)

			var is_fresh := _is_tick_fresh_for(simulator, i)
			simulator._run_simulation(NetworkTime.ticktime, i, is_fresh)
			_history_server._record_simulator_subjects(state_subjects, i + 1)
			_set_tick_simulated_for(simulator, i)

		# Restore messed up properties.
		simulator.listened_input_sender._restore_properties()

## 3- host puppet.
## - Simulate the current tick with its inputs.
## - If inputs are missing, predict them, see InputSender.
## - Save the resulting state as tick + 1, recorded in _after_tick.
## - Broadcast them.
func _handle_host_puppet_simulators(current_tick: int) -> void:
	# Host puppets are simulated at the current tick, like everything else.
	var simulated_tick := current_tick

	for simulator in _host_puppet_simulators:

		var input_sender := simulator.listened_input_sender

		# Inputs are read from each player's own history, not from the per tick
		# snapshot shared by all players. This way, whatever another player
		# sends can't keep this player from being simulated.
		# Apply the inputs of this tick, or the latest ones before it.
		var latest_input_tick := _apply_input_at(input_sender, simulated_tick)

		if latest_input_tick != simulated_tick:
			# The input didn't arrive in time, predict it from the latest one we
			# have. Same as a client filling a skipped stamp, see InputSender.
			_logger.debug("No input for @%d, predicting it", [simulated_tick])
			input_sender._set_input(input_sender._get_predicted_input(input_sender._get_input()))

		var is_fresh := _is_tick_fresh_for(simulator, simulated_tick)
		simulator._run_simulation(NetworkTime.ticktime, simulated_tick, is_fresh)

		_set_tick_simulated_for(simulator, simulated_tick)

# Steps every already-caught-up living projectile by a single tick.
# No need to restore world state for living projectiles. This runs after
# Simulators, so they see the world after this tick's movement, the state of
# current_tick + 1.
func _step_living_projectiles(current_tick: int) -> void:
	var simulated_tick := current_tick

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

# Steps the freshly registered projectiles up to current_tick (not included).
func _catch_up_fresh_projectiles(current_tick: int) -> void:
	if _fresh_registered_projectiles_by_tick.is_empty():
		return

	var simulated_tick := current_tick
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
		# Restore simulation aware collision nodes to the state after this
		# tick's movement, same as living projectiles see, see register_projectile.
		_simulated_collision_recorder.restore_tick(tick + 1)

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

# A tick is fresh the first time it's simulated for a node. Every peer only
# ever simulates forward into new ticks: the host one tick at a time, local
# authoritative peers re-simulate older ticks from the truth, then continue
# into new ones. So a tick is fresh exactly when it's newer than the latest
# tick simulated so far, no need to remember every tick. Example, local
# authoritative peer with a lead of 5:
#
#   at tick 100 | simulates 97 .. 105 | fresh: 105 only, 97 .. 104 were done
#   at tick 101 | simulates 98 .. 106 | fresh: 106 only
# Applies the inputs of input_sender recorded at or before tick, and returns
# the tick they were recorded at.
#
# If there are none at all, the default input is applied and -1 is returned.
# This happens right after a player spawned: the client re-simulates from the
# truth, which can be older than its first input, and the host simulates the
# player before its first input arrives. Without this, whatever the input
# properties hold at the moment would be applied for every such tick, e.g.
# this frame's mouse movement, once per tick:
#
#   client spawned @60, lead 8, first input stamped @68
#   truth @62 arrives, simulate 62 .. 69
#   62 .. 67 | no input  -> default input (was: this frame's live input)
#   68 .. 69 | recorded inputs
func _apply_input_at(input_sender: InputSender, tick: int) -> int:
	var input_subjects := input_sender._input_properties.get_subjects()
	var latest_input_tick := _history_server.get_latest_input_sender_for(input_subjects, tick)

	if latest_input_tick < 0:
		input_sender._set_input(input_sender._default_input)
	else:
		_history_server._restore_input_sender_subjects(input_subjects, tick)

	return latest_input_tick

func _is_tick_fresh_for(node: Node, tick: int) -> bool:
	return tick > _latest_simulated_ticks.get(node, -1)

func _set_tick_simulated_for(node: Node, tick: int) -> void:
	if tick > _latest_simulated_ticks.get(node, -1):
		_latest_simulated_ticks[node] = tick

# Ticks start over when NetworkTime starts, so does freshness.
func _reset_simulated_ticks() -> void:
	_latest_simulated_ticks.clear()

# Helper to get projectile debug name.
func _get_projectile_debug_name(p) -> String:
	return p.name if is_instance_valid(p) else "<invalid>"
