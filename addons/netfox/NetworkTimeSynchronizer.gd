extends Node

var sync_interval: float:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_interval", 1.0)
	set(v):
		push_error("Trying to set read-only variable sync_interval")

var sync_samples: int:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_samples", 8)
	set(v):
		push_error("Trying to set read-only variable sync_samples")

var sync_sample_interval: float:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_sample_interval", 0.1)
	set(v):
		push_error("Trying to set read-only variable sync_sample_interval")

var _remote_rtt: Dictionary = {}
var _remote_time: Dictionary = {}
var _remote_tick: Dictionary = {}
var _active: bool = false

signal on_sync(server_time: float, server_tick: int)
signal on_ping(peer_id: int, peer_time: float, peer_tick: int)

func start():
	_active = true
	_sync_time_loop(sync_interval)

func stop():
	_active = false

func get_real_time():
	return Time.get_ticks_msec() / 1000.0

func sync_time(id: int) -> float:
	# Source: https://daposto.medium.com/game-networking-2-time-tick-clock-synchronisation-9a0e76101fe5
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
		return NAN
	
	average = samples.reduce(func(a, b): return a + b) / samples.size()
	var latency = average / 2.0

	return last_remote_time + latency

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

@rpc("any_peer", "reliable", "call_remote")
func _request_ping():
	var sender = multiplayer.get_remote_sender_id()
	rpc_id(sender, "_respond_ping", NetworkTime.time, NetworkTime.tick)

@rpc("any_peer", "reliable", "call_remote")
func _respond_ping(peer_time: float, peer_tick: int):
	var sender = multiplayer.get_remote_sender_id()
	on_ping.emit(sender, peer_time, peer_tick)

func _sync_time_loop(interval: float):
	while true:
		var new_time = await sync_time(1)
		var new_tick = floor(new_time * NetworkTime.tickrate)
		new_time = new_tick * NetworkTime.ticktime # Sync to tick

		if not _active:
			# Make sure we don't emit any events if we've been stopped since
			break

		on_sync.emit(new_time, new_tick)
		await get_tree().create_timer(interval).timeout
