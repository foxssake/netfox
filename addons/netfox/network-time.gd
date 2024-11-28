extends Node
class_name _NetworkTime

## This class handles timing.
##
## @tutorial(NetworkTime Guide): https://foxssake.github.io/netfox/netfox/guides/network-time/

## Number of ticks per second.
##
## [i]read-only[/i], you can change this in the project settings
var tickrate: int:
	get:
		if sync_to_physics:
			return Engine.physics_ticks_per_second
		else:
			return ProjectSettings.get_setting("netfox/time/tickrate", 30)
	set(v):
		push_error("Trying to set read-only variable tickrate")

## Whether to sync the network ticks to physics updates.
##
## When set to true, tickrate will be the same as the physics ticks per second, 
## and the network tick loop will be run inside the physics update process.
##
## [i]read-only[/i], you can change this in the project settings
var sync_to_physics: bool:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_to_physics", false)
	set(v):
		push_error("Trying to set read-only variable sync_to_physics")

## Maximum number of ticks to simulate per frame.
##
## If the game itself runs slower than the configured tickrate, multiple ticks
## will be run in a single go. However, to avoid an endless feedback loop of
## running too many ticks in a frame, which makes the game even slower, which 
## results in even more ticks and so on, this setting is an upper limit on how
## many ticks can be simulated in a single go.
##
## [i]read-only[/i], you can change this in the project settings
var max_ticks_per_frame: int:
	get:
		return ProjectSettings.get_setting("netfox/time/max_ticks_per_frame", 8)
	set(v):
		push_error("Trying to set read-only variable max_ticks_per_frame")

## Current network time in seconds.
##
## Time is measured from the start of NetworkTime, in practice this is often the
## time from the server's start.
##
## Use this value in cases where timestamps need to be shared with the server.
##
## [i]Note:[/i] Time is continuously synced with the server. If the difference 
## between local and server time is above a certain threshold, this value will
## be adjusted.
##
## See [NetworkTimeSynchronizer].
## See the setting [code]"netfox/time/recalibrate_threshold"[/code].
##
## [i]read-only[/i]
var time: float:
	get:
		return float(_tick) / tickrate
	set(v):
		push_error("Trying to set read-only variable time")

## Current network time in ticks.
##
## Time is measured from the start of NetworkTime, in practice this is often the
## time from the server's start.
##
## Use this value in cases where timestamps need to be shared with the server.
##
## [i]Note:[/i] Time is continuously synced with the server. If the difference 
## between local and server time is above a certain threshold, this value will
## be adjusted.
##
## See [NetworkTimeSynchronizer].
## See the setting [code]"netfox/time/recalibrate_threshold"[/code].
##
## [i]read-only[/i]
var tick: int:
	get:
		return _tick
	set(v):
		push_error("Trying to set read-only variable tick")

## Threshold before recalibrating [member tick] and [member time].
##
## Time is continuously synced to the server. In case the time difference is 
## excessive between local and the server, both [code]tick[/code] and
## [code]time[/code] will be reset to the estimated server values.
## [br][br]
## This property determines the difference threshold in seconds for
## recalibration.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
## [br][br]
## @deprecated: Use [member _NetworkTimeSynchronizer.panic_threshold] instead.
var recalibrate_threshold: float:
	get:
		return ProjectSettings.get_setting("netfox/time/recalibrate_threshold", 8.0)
	set(v):
		push_error("Trying to set read-only variable recalibrate_threshold")

## Current network time in ticks on the server.
##
## This is value is only an estimate, and is regularly updated. This means that 
## this value can and probably will change depending on network conditions.
## [br][br]
## [i]read-only[/i]
## [br][br]
## @deprecated: Will return the same as [member tick].
var remote_tick: int:
	get:
		return tick
	set(v):
		push_error("Trying to set read-only variable remote_tick")

## Current network time in seconds on the server.
##
## This is value is only an estimate, and is regularly updated. This means that 
## this value can and probably will change depending on network conditions.
## [br][br]
## [i]read-only[/i]
## [br][br]
## @deprecated: Will return the same as [member time].
var remote_time: float:
	get:
		return time
	set(v):
		push_error("Trying to set read-only variable remote_time")

## Estimated roundtrip time to server.
##
## This value is updated regularly, during server time sync. Latency can be 
## estimated as half of the roundtrip time. Returns the same as [member 
## _NetworkTimeSynchronizer.rtt].
## [br][br]
## Will always be 0 on servers.
## [br][br]
## [i]read-only[/i]
var remote_rtt: float:
	get:
		return NetworkTimeSynchronizer.rtt
	set(v):
		push_error("Trying to set read-only variable remote_rtt")

## Current network time in ticks.
##
## On clients, this value is synced to the server [i]only once[/i] when joining
## the game. After that, it will increase monotonically, incrementing every 
## single tick.
## [br][br]
## When hosting, this value is simply the number of ticks since game start.
## [br][br]
## This property can be used for things that require a timer that is guaranteed
## to be linear, i.e. no jumps in time.
## [br][br]
## [i]read-only[/i]
## [br][br]
## @deprecated: Will return the same as [member tick].
var local_tick: int:
	get:
		return tick
	set(v):
		push_error("Trying to set read-only variable local_tick")

## Current network time in seconds.
##
## On clients, this value is synced to the server [i]only once[/i] when joining
## the game. After that, it will increase monotonically, incrementing every 
## single tick.
## [br][br]
## When hosting, this value is simply the seconds elapsed since game start.
## [br][br]
## This property can be used for things that require a timer that is guaranteed
## to be linear, i.e. no jumps in time.
## [br][br]
## [i]read-only[/i]
## [br][br]
## @deprecated: Will return the same as [member time].
var local_time: float:
	get:
		return time
	set(v):
		push_error("Trying to set read-only variable local_time")
		

## Amount of time a single tick takes, in seconds.
##
## This is the reverse of tickrate
##
## [i]read-only[/i]
var ticktime: float:
	get:
		return 1.0 / tickrate
	set(v):
		push_error("Trying to set read-only variable ticktime")

## Percentage of where we are in time for the current tick.
##
## 0.0 - the current tick just happened[br]
## 0.5 - we're halfway to the next tick[br]
## 1.0 - the next tick is right about to be simulated[br]
##
## [i]read-only[/i]
var tick_factor: float:
	get:
		if not sync_to_physics:
			return 1.0 - clampf((_next_tick_time - _last_process_time) * tickrate, 0, 1)
		else:
			return Engine.get_physics_interpolation_fraction()
	set(v):
		push_error("Trying to set read-only variable tick_factor")

## Multiplier to get from physics process speeds to tick speeds.
##
## Some methods, like CharacterBody's move_and_slide take velocity in units/sec
## and figure out the time delta on their own. However, they are not aware of 
## netfox's time, so motion is all wrong in a network tick. For example, the
## network ticks run at 30 fps, while the game is running at 60fps, thus 
## move_and_slide will also assume that it's running on 60fps, resulting in
## slower than expected movement.
##
## To circument this, you can multiply any velocities with this variable, and 
## get the desired speed. Don't forget to then divide by this value if it's a
## persistent variable ( e.g. CharacterBody's velocity ).
##
## NOTE: This works correctly both in regular and in physics frames, but may
## yield different values.
##
## [i]read-only[/i]
var physics_factor: float:
	get:
		if Engine.is_in_physics_frame():
			return Engine.physics_ticks_per_second / tickrate
		else:
			return ticktime / _process_delta
	set(v):
		push_error("Trying to set read-only variable physics_factor")

## The maximum clock stretch factor allowed.
##
## For more context on clock stretch, see [member clock_stretch_factor]. The 
## minimum allowed clock stretch factor is derived as 1.0 / clock_stretch_max. 
## Setting this to larger values will allow for quicker clock adjustment at the 
## cost of bigger deviations in game speed.
## [br][br]
## Make sure to adjust this value based on the game's needs.
## [br][br]
## [i]read-only[/i], you can change this in the project settings
var clock_stretch_max: float:
	get:
		return ProjectSettings.get_setting("netfox/time/max_time_stretch", 1.25)
	set(v):
		push_error("Trying to set read-only variable stretch_max")

## The currently used clock stretch factor.
##
## As the game progresses, the simulation clock may be ahead of, or behind the
## host's remote clock. To compensate, whenever the simulation clock is ahead of
## the remote clock, the game will slightly slow down, to allow the remote clock
## to catch up. When the remote clock is ahead of the simulation clock, the game
## will run slightly faster to catch up with the remote clock.
## [br][br]
## This value indicates the current clock speed multiplier. Values over 1.0 
## indicate speeding up, under 1.0 indicate slowing down.
## [br][br]
## See [member clock_stretch_max] for clock stretch bounds.[br]
## See [_NetworkTimeSynchronizer] for more on the reference- and simulation
## clock.
## [br][br]
## [i]read-only[/i]
var clock_stretch_factor: float:
	get:
		return _clock_stretch_factor

## The current estimated offset between the reference clock and the simulation
## clock.
## 
## Positive values mean the simulation clock is behind, and needs to run
## slightly faster to catch up. Negative values mean the simulation clock is
## ahead, and needs to slow down slightly.
## [br][br]
## See [member clock_stretch] for more clock speed adjustment.
## [br][br]
## [i]read-only[/i]
var clock_offset: float:
	get:
		# Offset is synced time - local time
		return NetworkTimeSynchronizer.get_time() - _clock.get_time()

## The current estimated offset between the reference clock and the remote
## clock.
##
## Positive values mean the reference clock is behind the remote clock. 
## Negative values mean the reference clock is ahead of the remote clock.
## [br][br]
## Returns the same as [member _NetworkTimeSynchronizer.remote_offset].
## [br][br]
## [i]read-only[/i]
var remote_clock_offset: float:
	get:
		return NetworkTimeSynchronizer.remote_offset

## Emitted before a tick loop is run.
signal before_tick_loop()

## Emitted before a tick is run.
signal before_tick(delta: float, tick: int)

## Emitted for every network tick.
signal on_tick(delta: float, tick: int)

## Emitted after every network tick.
signal after_tick(delta: float, tick: int)

## Emitted after the tick loop is run.
signal after_tick_loop()

## Emitted after time is synchronized.
##
## This happens once the NetworkTime is started, and the first time sync process
## concludes. When running as server, this is emitted instantly after started.
signal after_sync()

## Emitted after a client synchronizes their time.
##
## This is only emitted on the server, and is emitted when the client concludes
## their time sync process. This is useful as this event means that the client
## is ticking and gameplay has started on their end.
signal after_client_sync(peer_id: int)

# NetworkTime states
const _STATE_INACTIVE := 0
const _STATE_SYNCING := 1
const _STATE_ACTIVE := 2

var _state: int = _STATE_INACTIVE

var _tick: int = 0
var _was_paused: bool = false
var _initial_sync_done = false
var _process_delta: float = 0

var _next_tick_time: float = 0
var _last_process_time: float = 0.

var _clock: NetworkClocks.SteppingClock = NetworkClocks.SteppingClock.new()
var _clock_stretch_factor: float = 1.

var _synced_peers: Dictionary = {}

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NetworkTime")

## Start NetworkTime.
##
## Once this is called, time will be synchronized and ticks will be consistently
## emitted.
## [br][br]
## On clients, the initial time sync must complete before any ticks are emitted.
## [br][br]
## To check if this initial sync is done, see [method is_initial_sync_done]. If
## you need a signal, see [signal after_sync].
func start():
	if _state != _STATE_INACTIVE:
		return

	_tick = 0
	_initial_sync_done = false
	
	# Host is always synced, as their time is considered ground truth
	_synced_peers[1] = true
	
	NetworkTimeSynchronizer.start()
	_state = _STATE_SYNCING
	
	if not multiplayer.is_server():
		await NetworkTimeSynchronizer.on_initial_sync

		_tick = seconds_to_ticks(NetworkTimeSynchronizer.get_time())
		_initial_sync_done = true
		_state = _STATE_ACTIVE
		
		_submit_sync_success.rpc()
	else:
		_state = _STATE_ACTIVE
		_initial_sync_done = true

	# Remove clients from the synced cache when disconnected
	multiplayer.peer_disconnected.connect(func(peer): _synced_peers.erase(peer))

	_clock.set_time(NetworkTimeSynchronizer.get_time())
	_last_process_time = _clock.get_time()
	_next_tick_time = _clock.get_time()
	after_sync.emit()

## Stop NetworkTime.
##
## This will stop the time sync in the background, and no more ticks will be 
## emitted until the next start.
func stop():
	NetworkTimeSynchronizer.stop()
	_state = _STATE_INACTIVE
	_synced_peers.clear()

## Check if the initial time sync is done.
func is_initial_sync_done() -> bool:
	return _initial_sync_done

## Check if client's time sync is complete.
##
## Using this from a client is considered an error.
func is_client_synced(peer_id: int) -> bool:
	return _synced_peers.has(peer_id)

## Convert a duration of ticks to seconds.
func ticks_to_seconds(ticks: int) -> float:
	return ticks * ticktime

## Convert a duration of seconds to ticks.
func seconds_to_ticks(seconds: float) -> int:
	return int(seconds * tickrate)

## Calculate the duration between two ticks in seconds
##
## [i]Note:[/i] Returns negative values if tick_to is smaller than tick_from
func seconds_between(tick_from: int, tick_to: int) -> float:
	return ticks_to_seconds(tick_to - tick_from)

## Calculate the duration between two points in time as ticks
##
## [i]Note:[/i] Returns negative values if seconds_to is smaller than seconds_from
func ticks_between(seconds_from: float, seconds_to: float) -> int:
	return seconds_to_ticks(seconds_to - seconds_from)

static func _static_init():
	_NetfoxLogger.register_tag(func(): return "@%d" % NetworkTime.tick, -100)

func _loop():
	# Adjust local clock
	_clock.step(_clock_stretch_factor)
	var clock_diff = NetworkTimeSynchronizer.get_time() - _clock.get_time()
	
	# Ignore diffs under 1ms
	clock_diff = sign(clock_diff) * max(abs(clock_diff) - 0.001, 0.)
	
	var clock_stretch_min = 1. / clock_stretch_max
	# var clock_stretch_f = (1. + clock_diff / (1. * ticktime)) / 2.
	var clock_stretch_f = inverse_lerp(-ticktime, +ticktime, clock_diff)
	clock_stretch_f = clampf(clock_stretch_f, 0., 1.)

	var previous_stretch_factor = _clock_stretch_factor
	_clock_stretch_factor = lerpf(clock_stretch_min, clock_stretch_max, clock_stretch_f)
	
	# Detect editor pause
	var clock_step = _clock.get_time() - _last_process_time
	var clock_step_raw = clock_step / previous_stretch_factor
	if OS.has_feature("editor") and clock_step_raw > 1.:
			# Game stalled for a while, probably paused, don't run extra ticks
			# to catch up
			_was_paused = true
			_logger.debug("Game stalled for %.4fs, assuming it was a pause", [clock_step_raw])

	# Handle pause
	if _was_paused:
		_was_paused = false
		_next_tick_time += clock_step
	
	# Run tick loop if needed
	var ticks_in_loop = 0
	_last_process_time = _clock.get_time()
	while _next_tick_time < _last_process_time and ticks_in_loop < max_ticks_per_frame:
		if ticks_in_loop == 0:
			before_tick_loop.emit()

		before_tick.emit(ticktime, tick)
		on_tick.emit(ticktime, tick)
		after_tick.emit(ticktime, tick)
		
		_tick += 1
		ticks_in_loop += 1
		_next_tick_time += ticktime
	
	if ticks_in_loop > 0:
		after_tick_loop.emit()

func _process(delta):
	_process_delta = delta
	
	if _is_active() and not sync_to_physics:
		_loop()

func _physics_process(delta):
	if _is_active() and sync_to_physics:
		_loop()

func _notification(what):
	if what == NOTIFICATION_UNPAUSED:
		_was_paused = true

func _is_active() -> bool:
	return _state == _STATE_ACTIVE

@rpc("any_peer", "reliable", "call_local")
func _submit_sync_success():
	var peer_id = multiplayer.get_remote_sender_id()
	
	_logger.trace("Received time sync success from #%s, synced peers: %s", [peer_id, _synced_peers.keys()])
	
	if not _synced_peers.has(peer_id):
		_synced_peers[peer_id] = true
		after_client_sync.emit(peer_id)
		_logger.debug("Peer #%s is now on time!", [peer_id])
