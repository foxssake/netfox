extends Node

const NETWORK_TICK_LOOP_DURATION_MONITOR: StringName = "netfox/Network loop duration (ms)"
const ROLLBACK_TICK_LOOP_DURATION_MONITOR: StringName = "netfox/Rollback loop duration (ms)"
const NETWORK_TICKS_MONITOR: StringName = "netfox/Network ticks simulated"
const ROLLBACK_TICKS_MONITOR: StringName = "netfox/Rollback ticks simulated"

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

	return OS.is_debug_build()

func _ready():
	if not is_enabled():
		_logger.debug("Network performance disabled")
		return

	_logger.debug("Network performance enabled, registering performance monitors")
	Performance.add_custom_monitor(NETWORK_TICK_LOOP_DURATION_MONITOR, func(): return _network_loop_duration * 1000)
	Performance.add_custom_monitor(ROLLBACK_TICK_LOOP_DURATION_MONITOR, func(): return _rollback_loop_duration * 1000)
	Performance.add_custom_monitor(NETWORK_TICKS_MONITOR, func(): return _network_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICKS_MONITOR, func(): return _rollback_ticks)
	
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
