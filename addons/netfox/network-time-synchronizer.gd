extends Node

## Time between syncs, in seconds.
##
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_interval: float:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_interval", 1.0)
	set(v):
		push_error("Trying to set read-only variable sync_interval")

## Number of measurements ( samples ) to take to guess latency.
##
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_samples: int:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_samples", 8)
	set(v):
		push_error("Trying to set read-only variable sync_samples")

## Time between samples in a single sync process.
##
## [i]read-only[/i], you can change this in the Netfox project settings
var sync_sample_interval: float:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_sample_interval", 0.1)
	set(v):
		push_error("Trying to set read-only variable sync_sample_interval")

var _remote_rtt: Dictionary = {}
var _remote_time: Dictionary = {}
var _remote_tick: Dictionary = {}
var _active: bool = false

## Event emitted when a time sync process completes
signal on_sync(server_time: float, server_tick: int, rtt: float)

## Event emitted when a response to a ping request arrives.
signal on_ping(peer_id: int, peer_time: float, peer_tick: int)

## Start the time synchronization loop.
##
## Starting multiple times has no effect.
func start():
	if _active:
		return

	_active = true
	_sync_time_loop(sync_interval)

## Stop the time synchronization loop.
func stop():
	_active = false

## Get the amount of time passed since Godot has started, in seconds.
func get_real_time():
	return Time.get_ticks_msec() / 1000.0

## Estimate the time at the given peer, in seconds.
##
## While this is a coroutine, so it won't block your game, this can take multiple
## seconds, depending on latency, number of samples and sample interval.
##
## Returns a triplet of the following:
## [ol]
## last_remote_time - Latest timestamp received from target
## rtt - Estimated roundtrip time to target
## synced_time - Estimated time at target
## [/ol]
func sync_time(id: int) -> Array[float]:
	_remote_rtt.clear()
	_remote_time.clear()
	_remote_tick.clear()
	
	for i in range(sync_samples):
		get_rtt(id, i)
		await get_tree().create_timer(sync_sample_interval).timeout
	
	# Wait for all samples to run through
	while _remote_rtt.size() != sync_samples:
		await get_tree().process_frame
	
	var samples = _remote_rtt.values().duplicate()
	var last_remote_time = _remote_time.values().max()
	samples.sort()
	var average = samples.reduce(func(a, b): return a + b) / samples.size()
	
	# Reject samples that are too far away from average
	var deviation_threshold = 1
	samples = samples.filter(func(s): return (s - average) / average < deviation_threshold)
	
	# Return NAN if none of the samples fit within threshold
	# Should be rare, but technically possible
	if samples.is_empty():
		return [NAN, NAN, NAN]
	
	average = samples.reduce(func(a, b): return a + b) / samples.size()
	var rtt = average
	var latency = rtt / 2.0

	return [last_remote_time, rtt, last_remote_time + latency]

## Get roundtrip time to a given peer, in seconds.
func get_rtt(id: int, sample_id: int = -1) -> float:
	if id == multiplayer.get_unique_id():
		return 0
	
	var trip_start = get_real_time()
	rpc_id(id, "_request_ping")
	var response = await on_ping
	var trip_end = get_real_time()
	var rtt = trip_end - trip_start
	
	_remote_rtt[sample_id] = rtt
	_remote_time[sample_id] = response[1]
	_remote_tick[sample_id] = response[2]
	return rtt

func _sync_time_loop(interval: float):
	while true:
		var sync_result = await sync_time(1)
		var rtt = sync_result[1]
		var new_time = sync_result[2]

		if not _active:
			# Make sure we don't emit any events if we've been stopped since
			break
		if new_time == NAN:
			# Skip if sync has failed
			continue

		var new_tick = floor(new_time * NetworkTime.tickrate)
		new_time = NetworkTime.ticks_to_seconds(new_tick) # Sync to tick

		on_sync.emit(new_time, new_tick, rtt)
		await get_tree().create_timer(interval).timeout

@rpc("any_peer", "reliable", "call_remote")
func _request_ping():
	var sender = multiplayer.get_remote_sender_id()
	rpc_id(sender, "_respond_ping", NetworkTime.time, NetworkTime.tick)

@rpc("any_peer", "reliable", "call_remote")
func _respond_ping(peer_time: float, peer_tick: int):
	var sender = multiplayer.get_remote_sender_id()
	on_ping.emit(sender, peer_time, peer_tick)
