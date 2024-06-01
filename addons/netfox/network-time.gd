extends Node
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
## When set to true, tickrate and the custom timer is ignored, and a network 
## tick will be done on every physics frame.
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

## Threshold before recalibrating [code]tick[/code] and [code]time[/code].
##
## Time is continuously synced to the server. In case the time difference is 
## excessive between local and the server, both [code]tick[/code] and
## [code]time[/code] will be reset to the estimated server values.
##
## This property determines the difference threshold in seconds for
## recalibration.
##
## [i]read-only[/i], you can change this in the project settings
var recalibrate_threshold: float:
	get:
		return ProjectSettings.get_setting("netfox/time/recalibrate_threshold", 8.0)
	set(v):
		push_error("Trying to set read-only variable recalibrate_threshold")

## Current network time in ticks on the server.
##
## This is value is only an estimate, and is regularly updated. This means that 
## this value can and probably will change depending on network conditions.
##
## [i]read-only[/i]
var remote_tick: int:
	get:
		return _remote_tick
	set(v):
		push_error("Trying to set read-only variable remote_tick")

## Current network time in seconds on the server.
##
## This is value is only an estimate, and is regularly updated. This means that 
## this value can and probably will change depending on network conditions.
##
## [i]read-only[/i]
var remote_time: float:
	get:
		return float(_remote_tick) / tickrate
	set(v):
		push_error("Trying to set read-only variable remote_time")

## Estimated roundtrip time to server.
##
## This value is updated regularly, during server time sync. Latency can be 
## estimated as half of the roundtrip time.
##
## Will always be 0 on servers.
##
## [i]read-only[/i]
var remote_rtt: float:
	get:
		return _remote_rtt
	set(v):
		push_error("Trying to set read-only variable remote_rtt")

## Current network time in ticks.
##
## On clients, this value is synced to the server [i]only once[/i] when joining
## the game. After that, it will increase monotonically, incrementing every 
## single tick.
##
## When hosting, this value is simply the number of ticks since game start.
##
## This property can be used for things that require a timer that is guaranteed
## to be linear, i.e. no jumps in time.
##
## [i]read-only[/i]
var local_tick: int:
	get:
		return _local_tick
	set(v):
		push_error("Trying to set read-only variable local_tick")

## Current network time in seconds.
##
## On clients, this value is synced to the server [i]only once[/i] when joining
## the game. After that, it will increase monotonically, incrementing every 
## single tick.
##
## When hosting, this value is simply the seconds elapsed since game start.
##
## This property can be used for things that require a timer that is guaranteed
## to be linear, i.e. no jumps in time.
##
## [i]read-only[/i]
var local_time: float:
	get:
		return float(_local_tick) / tickrate
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

var _tick: int = 0
var _active: bool = false
var _initial_sync_done = false
var _process_delta: float = 0

var _next_tick_time: float = 0
var _last_process_time: float = 0.

var _remote_rtt: float = 0
var _remote_tick: int = 0
var _local_tick: int = 0

# Cache the synced clients, as the rpc call itself may arrive multiple times
# ( for some reason? )
var _synced_clients: Dictionary = {}

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NetworkTime")

## Start NetworkTime.
##
## Once this is called, time will be synchronized and ticks will be consistently
## emitted.
##
## On clients, the initial time sync must complete before any ticks are emitted.
##
## To check if this initial sync is done, see [method is_initial_sync_done]. If
## you need a signal, see [signal after_sync].
func start():
	if _active:
		return

	_tick = 0
	_remote_tick = 0
	_local_tick = 0
	_remote_rtt = 0
	_initial_sync_done = false
	
	after_client_sync.connect(func(pid):
		_logger.debug("Client #%s is now on time!" % [pid])
	)
	
	if not multiplayer.is_server():
		NetworkTimeSynchronizer.start()
		await NetworkTimeSynchronizer.on_sync
		_tick = _remote_tick
		_local_tick = _remote_tick
		_initial_sync_done = true
		_active = true
		_next_tick_time = _get_os_time()
		after_sync.emit()
		
		rpc_id(1, "_submit_sync_success")
	else:
		_active = true
		_initial_sync_done = true
		_next_tick_time = _get_os_time()
		after_sync.emit()
		
		# Remove clients from the synced cache when disconnected
		multiplayer.peer_disconnected.connect(func(peer): _synced_clients.erase(peer))

## Stop NetworkTime.
##
## This will stop the time sync in the background, and no more ticks will be 
## emitted until the next start.
func stop():
	NetworkTimeSynchronizer.stop()
	_active = false

## Check if the initial time sync is done.
func is_initial_sync_done() -> bool:
	return _initial_sync_done

## Check if client's time sync is complete.
##
## Using this from a client is considered an error.
func is_client_synced(peer_id: int) -> bool:
	if not multiplayer.is_server():
		_logger.error("Trying to check if client is synced from another client!")
		return false
	else:
		return _synced_clients.has(peer_id)

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

func _ready():
	NetworkTimeSynchronizer.on_sync.connect(_handle_sync)

func _process(delta):
	# Use OS delta to determine if the game's paused from editor, or through the SceneTree
	var os_delta = _get_os_time() - _last_process_time
	var is_delta_mismatch = os_delta / delta > 4. and os_delta > .5
	
	# Adjust next tick time if the game is paused, so we don't try to "catch up" after unpausing
	if (is_delta_mismatch and Engine.is_editor_hint()) or get_tree().paused:
		_next_tick_time += os_delta

	_process_delta = delta
	_last_process_time += os_delta

	# Run tick loop if needed
	if _active and not sync_to_physics:
		var ticks_in_loop = 0
		while _next_tick_time < _last_process_time and ticks_in_loop < max_ticks_per_frame:
			if ticks_in_loop == 0:
				before_tick_loop.emit()

			_run_tick()

			ticks_in_loop += 1
			_next_tick_time += ticktime
		
		if ticks_in_loop > 0:
			after_tick_loop.emit()

func _physics_process(delta):
	if _active and sync_to_physics and not get_tree().paused:
		# Run a single tick every physics frame
		before_tick_loop.emit()
		_run_tick()
		after_tick_loop.emit()

func _run_tick():
	before_tick.emit(ticktime, tick)
	on_tick.emit(ticktime, tick)
	after_tick.emit(ticktime, tick)
	
	_tick += 1
	_remote_tick +=1
	_local_tick += 1

func _get_os_time() -> float:
	return Time.get_ticks_msec() / 1000.

func _handle_sync(server_time: float, server_tick: int, rtt: float):
	_remote_tick = server_tick
	_remote_rtt = rtt
	
	# Adjust tick if it's too far away from remote
	if absf(seconds_between(tick, remote_tick)) > recalibrate_threshold and _initial_sync_done:
		_logger.error("Large difference between estimated remote time and local time!")
		_logger.error("Local time: %s; Remote time: %s" % [time, remote_time])
		_tick = _remote_tick

@rpc("any_peer", "reliable", "call_remote")
func _submit_sync_success():
	var peer_id = multiplayer.get_remote_sender_id()
	
	if not _synced_clients.has(peer_id):
		_synced_clients[peer_id] = true
		after_client_sync.emit(multiplayer.get_remote_sender_id())
