extends Node
## This class handles timing.
##
## Timing in a multiplayer game has two important jobs - to make sure everyone
## moves to the next tick at the same rate, and that the game time is approximately
## the same at everyone.
##
## The former is handled by this class and its signals, and the latter is done 
## by [NetworkTimeSynchronizer] in the background.
##
## A separate timer is provided for network ticks, making the network game 
## update rate independent from rendering or physics frames.

## Number of ticks per second.
##
## [i]read-only[/i], you can change this in the project settings
var tickrate: int:
	get:
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
## [i]Note:[/i] This is continuously synchronized with the server, so its value
## may jump a bit, both forwards and backwards. See [NetworkTimeSynchronizer].
##
## [i]read-only[/i]
var time: float:
	get:
		return _time
	set(v):
		push_error("Trying to set read-only variable time")

## Current network time in ticks.
##
## Time is measured from the start of NetworkTime, in practice this is often the
## time from the server's start.
##
## [i]Note:[/i] This is continuously synchronized with the server, so its value
## may jump a bit, both forwards and backwards. See [NetworkTimeSynchronizer].
##
## [i]read-only[/i]
var tick: int:
	get:
		return _tick
	set(v):
		push_error("Trying to set read-only variable tick")

## Amount of time a single tick takes, in seconds.
##
## This is the reverse of tickrate
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
var tick_factor: float:
	get:
		return 1.0 - clampf(_next_tick * tickrate, 0, 1)
	set(v):
		push_error("Trying to set read-only variable tick_factor")

## Multiplier to get from physics process speeds to tick speeds.
##
## Some methods, like CharacterBody's move_and_slide always assume that we're
## running a physics update, and it will also assume that the delta time is the
## physics process' delta time. This means that if you we to call these methods
## from a network tick, the speeds will be all wrong, because e.g. the network
## ticks run at 30 fps, while the physics process is set to 60fps, thus 
## move_and_slide will also assume that it's running on 60fps, resulting in
## slower than expected movement.
##
## To circument this, you can multiply any velocities with this variable, and 
## get the desired speed. Don't forget to then divide by this value if it's a
## persistent variable ( e.g. CharacterBody's velocity ).
var physics_factor: float:
	get:
		if not sync_to_physics:
			return Engine.physics_ticks_per_second / tickrate
		else:
			return 1.0
	set(v):
		push_error("Trying to set read-only variable physics_factor")

## Emitted before a tick loop is run.
signal before_tick_loop()

# TODO: Add as feature
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

var _time: float = 0
var _tick: int = 0
var _next_tick: float = 0
var _active: bool = false
var _initial_sync_done = false

func _ready():
	NetworkTimeSynchronizer.on_sync.connect(_handle_sync)

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

	_time = 0
	_initial_sync_done = false
	
	if not multiplayer.is_server():
		NetworkTimeSynchronizer.start()
		await NetworkTimeSynchronizer.on_sync
		_initial_sync_done = true
		_active = true
		after_sync.emit()
	else:
		_active = true
		_initial_sync_done = true
		after_sync.emit()

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

func _process(delta):
	if _active and not sync_to_physics:
		_next_tick -= delta
		
		var ticks_in_loop = 0
		while _next_tick < 0 and ticks_in_loop < max_ticks_per_frame:
			if ticks_in_loop == 0:
				before_tick_loop.emit()

			before_tick.emit(ticktime, tick)
			on_tick.emit(ticktime, tick)
			after_tick.emit(ticktime, tick)

			_tick += 1
			_time += ticktime
			ticks_in_loop += 1
			_next_tick += ticktime
		
		if ticks_in_loop > 0:
			after_tick_loop.emit()

func _physics_process(delta):
	if _active and sync_to_physics:
		# Run a single tick every physics frame
		before_tick_loop.emit()
		before_tick.emit(delta, tick)
		on_tick.emit(delta, tick)
		after_tick.emit(delta, tick)
		after_tick_loop.emit()

func _handle_sync(server_time: float, server_tick: int):
	_time = server_time
	_tick = server_tick
