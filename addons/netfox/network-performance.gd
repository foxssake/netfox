extends Node

const NETWORK_LOOP_DURATION_MONITOR: StringName = "netfox/Network loop duration (ms)"
const ROLLBACK_LOOP_DURATION_MONITOR: StringName = "netfox/Rollback loop duration (ms)"
const NETWORK_TICKS_MONITOR: StringName = "netfox/Network ticks simulated"
const ROLLBACK_TICKS_MONITOR: StringName = "netfox/Rollback ticks simulated"
const ROLLBACK_TICK_DURATION_MONITOR: StringName = "netfox/Rollback tick duration (ms)"

var _network_loop_start: float = 0
var _network_loop_duration: float = 0

var _network_ticks: int = 0
var _network_ticks_accum: int = 0

var _rollback_loop_start: float = 0
var _rollback_loop_duration: float = 0

var _rollback_ticks: int = 0
var _rollback_ticks_accum: int = 0

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("NetworkPerformance")

func is_enabled():
	if OS.has_feature("netfox_noperf"):
		return false
	
	if OS.has_feature("netfox_perf"):
		return true

	# This returns true in the editor too
	return OS.is_debug_build()

## Get time spent in the last network tick loop, in millisec.
## [br]
## Note that this also includes time spent in the rollback tick loop.
func get_network_loop_duration_ms() -> float:
	return _network_loop_duration * 1000

## Get the number of ticks simulated in the last network tick loop.
func get_network_ticks() -> int:
	return _network_ticks

## Get time spent in the last rollback tick loop, in millisec.
func get_rollback_loop_duration_ms() -> float:
	return _rollback_loop_duration * 1000

## Get the number of ticks resimulated in the last rollback tick loop.
func get_rollback_ticks() -> int:
	return _rollback_ticks

## Get the average amount of time spent in a rollback tick during the last
## rollback loop, in millisec.
func get_rollback_tick_duration_ms() -> float:
	return _rollback_loop_duration * 1000 / maxi(_rollback_ticks, 1)

func _ready():
	if not is_enabled():
		_logger.debug("Network performance disabled")
		return

	_logger.debug("Network performance enabled, registering performance monitors")
	Performance.add_custom_monitor(NETWORK_LOOP_DURATION_MONITOR, get_network_loop_duration_ms)
	Performance.add_custom_monitor(ROLLBACK_LOOP_DURATION_MONITOR, get_rollback_loop_duration_ms)
	Performance.add_custom_monitor(NETWORK_TICKS_MONITOR, get_network_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICKS_MONITOR, get_rollback_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICK_DURATION_MONITOR, get_rollback_tick_duration_ms)
	
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.on_tick.connect(_on_network_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	
	NetworkRollback.before_loop.connect(_before_rollback_loop)
	NetworkRollback.on_process_tick.connect(_on_rollback_tick)
	NetworkRollback.after_loop.connect(_after_rollback_loop)

func _before_tick_loop():
	_network_loop_start = _time()
	_network_ticks_accum = 0

func _on_network_tick(_dt, _t):
	_network_ticks_accum += 1

func _after_tick_loop():
	_network_loop_duration = _time() - _network_loop_start
	_network_ticks = _network_ticks_accum

func _before_rollback_loop():
	_rollback_loop_start = _time()
	_rollback_ticks_accum = 0

func _on_rollback_tick(_t):
	_rollback_ticks_accum += 1

func _after_rollback_loop():
	_rollback_loop_duration = _time() - _rollback_loop_start
	_rollback_ticks = _rollback_ticks_accum

func _time() -> float:
	return Time.get_unix_time_from_system()
