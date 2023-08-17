extends Node

var tickrate: int:
	get:
		return ProjectSettings.get_setting("netfox/time/tickrate", 30)
	set(v):
		push_error("Trying to set read-only variable tickrate")

var sync_to_physics: bool:
	get:
		return ProjectSettings.get_setting("netfox/time/sync_to_physics", false)
	set(v):
		push_error("Trying to set read-only variable sync_to_physics")

var max_ticks_per_frame: int:
	get:
		return ProjectSettings.get_setting("netfox/time/max_ticks_per_frame", 8)
	set(v):
		push_error("Trying to set read-only variable max_ticks_per_frame")

var time: float:
	get:
		return _time
	set(v):
		push_error("Trying to set read-only variable time")

var tick: int:
	get:
		return _tick
	set(v):
		push_error("Trying to set read-only variable tick")

var ticktime: float:
	get:
		return 1.0 / tickrate
	set(v):
		push_error("Trying to set read-only variable ticktime")

var tick_factor: float:
	get:
		return 1.0 - clampf(_next_tick * tickrate, 0, 1)
	set(v):
		push_error("Trying to set read-only variable tick_factor")

var physics_factor: float:
	get:
		return Engine.physics_ticks_per_second / tickrate
	set(v):
		push_error("Trying to set read-only variable physics_factor")

signal before_tick_loop
signal on_tick(delta: float)
signal after_tick(delta: float)
signal after_tick_loop

var _time: float = 0
var _tick: int = 0
var _next_tick: float = 0
var _active: bool = false

func _ready():
	NetworkTimeSynchronizer.on_sync.connect(_handle_sync)

func start():
	_time = 0
	
	if not multiplayer.is_server():
		NetworkTimeSynchronizer.start()
		await NetworkTimeSynchronizer.on_sync
		_active = true
	else:
		_active = true

func stop():
	NetworkTimeSynchronizer.stop()
	_active = false

func _process(delta):
	if _active and not sync_to_physics:
		_next_tick -= delta
		
		var ticks_in_loop = 0
		while _next_tick < 0 and ticks_in_loop < max_ticks_per_frame:
			if ticks_in_loop == 0:
				before_tick_loop.emit()

			on_tick.emit(ticktime)
			after_tick.emit(ticktime)

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
		on_tick.emit(delta)
		after_tick.emit(delta)
		after_tick_loop.emit()

func _handle_sync(server_time: float, server_tick: int):
	_time = server_time
	_tick = server_tick
