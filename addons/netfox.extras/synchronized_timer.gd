@icon("res://addons/netfox.extras/icons/synchronized-timer.svg")
class_name SynchronizedTimer
extends Timer
## A peer-to-peer synchronized Timer node. 
## Call [method start_synced] and [method stop_synced]
## on a multiplayer authority to start/stop and synchronize the timer.
## 
## [color=orange][b]WARNING: [/b][/color] Using [member Timer.autostart] 
## may not properly synchronize your node!


## Synchronization interval for this timer (in [_NetworkTime] ticks)
@export var sync_interval: int = 30
## Max allowed drift (in seconds) between local and the authority's time before a correction is needed
@export var max_drift: float = 0.07
 
var starting_tick: int = 0
var last_sync_tick: int = 0
 
var _duration: float = 0.0     # full cycle length; wait_time can be temporarily altered by start(time)
var _last_stop_tick: int = -1  # ignores stale pings that arrive after a stop
var _completed: bool = false   # already timed out locally, ignore late pings
 
 
func _ready() -> void:
	NetworkTime.on_tick.connect(_on_network_time_tick)
	multiplayer.peer_connected.connect(_on_peer_connected)
 
 
## (Authority only!) Starts the timer on every peer. Uses [member Timer.wait_time] if [param time_seconds][code] <= 0[/code].
func start_synced(time_seconds: float = -1.0) -> void:
	if not multiplayer.is_multiplayer_authority():
		push_warning("SynchronizedTimer: start_synced() must be called by the authority.")
		return
	var duration: float = wait_time if time_seconds <= 0.0 else time_seconds
	remote_start.rpc(NetworkTime.tick, duration, duration)
 
 
## (Authority only!) Stops the timer on all peers.
func stop_synced() -> void:
	if not multiplayer.is_multiplayer_authority():
		push_warning("SynchronizedTimer: stop_synced() must be called by the authority.")
		return
	remote_stop.rpc(NetworkTime.tick)
 
## The RPC used by the authority to start the timer on its peers.
## [param tick]: tick at which the message was sent.
## [param remaining_time]: seconds left on the authority at that tick.
@rpc("authority", "call_local", "reliable")
func remote_start(tick: int, remaining_time: float, duration: float) -> void:
	# A client can't compare ticks until its clock has synced with the authority
	if not NetworkTime.is_initial_sync_done():
		await NetworkTime.after_sync
	if tick <= _last_stop_tick:
		return
 
	_duration = duration
	_completed = false
	starting_tick = tick - NetworkTime.seconds_to_ticks(duration - remaining_time)
	last_sync_tick = tick
 
	var remaining := remaining_time - NetworkTime.ticks_to_seconds(NetworkTime.tick - tick)
	if remaining <= 0.0:
		# Message took longer than the time left
		if one_shot:
			stop()
			_completed = true
			timeout.emit()
			return
		remaining = fposmod(remaining, duration)
		if remaining <= 0.0:
			remaining = duration
	_begin(remaining)
 
 
@rpc("authority", "call_local", "reliable")
func remote_stop(tick: int) -> void:
	_last_stop_tick = tick
	stop()
 
 
## Periodic drift correction, sent by the authority every [member sync_interval] ticks.
@rpc("authority", "call_remote", "unreliable_ordered")
func sync_ping(tick: int, remaining_time: float, duration: float) -> void:
	if not NetworkTime.is_initial_sync_done() or tick <= _last_stop_tick:
		return
 
	var remaining := remaining_time - NetworkTime.ticks_to_seconds(NetworkTime.tick - tick)
	if remaining <= 0.0:
		return
 
	_duration = duration
	if is_stopped():
		# Missed the start message, or a repeating timer stopped; join the running timer
		if _completed and one_shot:
			return
		_begin(remaining)
	elif absf(time_left - remaining) > max_drift:
		_begin(remaining)
 
 
func _on_network_time_tick(_delta: float, tick: int) -> void:
	if multiplayer and not multiplayer.is_multiplayer_authority() or is_stopped():
		return
	if tick - last_sync_tick >= sync_interval:
		last_sync_tick = tick
		sync_ping.rpc(tick, time_left, _duration)
 
 
func _on_peer_connected(peer: int) -> void:
	# Late joiners: send the current state so they can catch up
	if multiplayer.is_multiplayer_authority() and not is_stopped():
		remote_start.rpc_id(peer, NetworkTime.tick, time_left, _duration)
 
 
func _on_timeout() -> void:
	if one_shot:
		_completed = true
 
 
## Starts with a custom remaining time, but keeps the full cycle length for repeating timers.
func _begin(remaining: float) -> void:
	start(remaining) # also overwrites wait_time...
	if _duration > 0.0:
		wait_time = _duration # ...so restore it. this doesn't change time_left
	if not timeout.is_connected(_on_timeout):
		timeout.connect(_on_timeout)
