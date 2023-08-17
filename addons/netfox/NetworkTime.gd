extends Node

var tickrate: int:
	get:
		return ProjectSettings.get_setting("netfox/time/tickrate", 30)

var sync_to_physics: bool:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_to_physics", false)

var max_ticks_per_frame: int:
	get:
		return ProjectSettings.get_setting("netfox/time/max_ticks_per_frame", 8)

var sync_interval: float:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_interval", 1.0)

var sync_samples: int:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_samples", 8)

var sync_sample_interval: float:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_sample_interval", 0.1)

var time: float:
	get:
		return time

var tick: int:
	get:
		return tick

var ticktime: float:
	get:
		return 1.0 / tickrate

var tickfactor: float:
	get:
		return 1.0 - clampf(_next_tick * tickrate, 0, 1)

var last_remote_time: float = -1:
	get:
		return last_remote_time

var last_remote_tick: int = -1:
	get:
		return last_remote_tick

signal before_tick_loop
signal on_tick(delta: float)
signal after_tick(delta: float)
signal after_tick_loop
signal on_sync

signal on_ping(peer_id: int, peer_time: float, peer_tick: int)

var _next_tick: float = 0
var _active: bool = false

func start():
	time = 0
	
	if not multiplayer.is_server():
		_sync_time_loop(sync_interval)
		await on_sync
		_active = true
	else:
		_active = true

func stop():
	_active = false

func get_real_time():
	return Time.get_ticks_msec() / 1000.0

func sync_time(id: int) -> float:
	# Source: https://daposto.medium.com/game-networking-2-time-tick-clock-synchronisation-9a0e76101fe5
	var samples = []
	for i in range(sync_samples - 1):
		await get_tree().create_timer(sync_sample_interval).timeout
		samples.push_back(await get_rtt(id))
	
	samples.sort()
	var average = samples.reduce(func(a, b): return a + b) / samples.size()
	
	# Reject samples that are too far away from average
	var deviation_threshold = 1
	samples = samples.filter(func(s): return (s - average) / average < deviation_threshold)
	average = samples.reduce(func(a, b): return a + b) / samples.size()
	var latency = average / 2.0
	print("Latency: %s <- %s" % [latency, samples])

	return last_remote_time + latency

func get_rtt(id: int) -> float:
	if id == multiplayer.get_unique_id():
		return 0
	
	var trip_start = get_real_time()
	rpc_id(id, "_request_ping")
	var response = await on_ping
	var trip_end = get_real_time()
	
	last_remote_time = response[1]
	last_remote_tick = response[2]
	return trip_end - trip_start

func _process(delta):
	if _active and not sync_to_physics:
		_next_tick -= delta
		
		var ticks_in_loop = 0
		while _next_tick < 0 and ticks_in_loop < max_ticks_per_frame:
			if ticks_in_loop == 0:
				before_tick_loop.emit()

			on_tick.emit(ticktime)
			after_tick.emit(ticktime)

			tick += 1
			time += ticktime
			ticks_in_loop += 1
			_next_tick += ticktime
		
		if ticks_in_loop > 0:
			after_tick_loop.emit()

func _physics_process(delta):
	if _active and sync_to_physics:
		# Run a single tick every physics frame
		before_tick_loop.emit()
		on_tick.emit(delta)
		after_tick.emit(delta)
		after_tick_loop.emit()

func _sync_time_loop(interval: float):
	while true:
		var new_time = await sync_time(1)
		var new_tick = floor(new_time * tickrate)
		new_time = new_tick * ticktime # Sync to tick
		print("Syncing time %s -> %s, #%s -> #%s" % [time, new_time, tick, new_tick])
		time = new_time
		tick = new_tick
		on_sync.emit()
		
		if not _active:
			break
		
		await get_tree().create_timer(interval).timeout

@rpc("any_peer", "reliable", "call_remote")
func _request_ping():
	var sender = multiplayer.get_remote_sender_id()
	rpc_id(sender, "_respond_ping", time, tick)

@rpc("any_peer", "reliable", "call_remote")
func _respond_ping(peer_time: float, peer_tick: int):
	var sender = multiplayer.get_remote_sender_id()
	on_ping.emit(sender, peer_time, peer_tick)
