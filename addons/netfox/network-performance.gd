extends Node
class_name _NetworkPerformance

const NETWORK_LOOP_DURATION_MONITOR: StringName = &"netfox/Network loop duration (ms)"
const ROLLBACK_LOOP_DURATION_MONITOR: StringName = &"netfox/Rollback loop duration (ms)"
const NETWORK_TICKS_MONITOR: StringName = &"netfox/Network ticks simulated"
const ROLLBACK_TICKS_MONITOR: StringName = &"netfox/Rollback ticks simulated"
const ROLLBACK_TICK_DURATION_MONITOR: StringName = &"netfox/Rollback tick duration (ms)"
const ROLLBACK_NODES_SIMULATED_MONITOR: StringName = &"netfox/Rollback nodes simulated"
const ROLLBACK_NODES_SIMULATED_PER_TICK_MONITOR: StringName = &"netfox/Rollback nodes simulated per tick (avg)"

const FULL_STATE_PROPERTIES_COUNT: StringName = &"netfox/Full state properties count"
const SENT_STATE_PROPERTIES_COUNT: StringName = &"netfox/Sent state properties count"
const SENT_STATE_PROPERTIES_RATIO: StringName = &"netfox/Sent state properties ratio"

var _network_loop_start: float = 0
var _network_loop_duration: float = 0

var _network_ticks: int = 0
var _network_ticks_accum: int = 0

var _rollback_loop_start: float = 0
var _rollback_loop_duration: float = 0

var _rollback_ticks: int = 0
var _rollback_ticks_accum: int = 0

var _rollback_nodes_simulated: int = 0
var _rollback_nodes_simulated_accum: int = 0

var _full_state_props: int = 0
var _full_state_props_accum: int = 0

var _sent_state_props: int = 0
var _sent_state_props_accum: int = 0

static var _logger: NetfoxLogger = NetfoxLogger._for_netfox("NetworkPerformance")

## Check if performance monitoring is enabled.
## [br][br]
## By default, monitoring is only enabled in debug builds 
## ( see [method OS.is_debug_build] ). [br]
## Can be forced on with the [code]netfox_perf[/code] feature tag. [br]
## Can be forced off with the [code]netfox_noperf[/code] feature tag.
func is_enabled() -> bool:
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

## Get the number of nodes simulated during the last rollback loop.
func get_rollback_nodes_simulated() -> int:
	return _rollback_nodes_simulated

## Get the number of nodes simulated per tick on average during the last
## rollback loop.
func get_rollback_nodes_simulated_per_tick() -> float:
	return _rollback_nodes_simulated / maxf(1., _rollback_ticks)

func push_rollback_nodes_simulated(count: int):
	_rollback_nodes_simulated_accum += count

## Get the number of properties in the full state recorded during the last tick
## loop.
func get_full_state_props_count() -> int:
	return _full_state_props

## Get the number of properties actually sent during the last tick loop.
func get_sent_state_props_count() -> int:
	return _sent_state_props

## Get the ratio of sent properties count to full state properties count.
##
## See [member get_full_state_props_count][br]
## See [member get_sent_state_props_count]
func get_sent_state_props_ratio() -> float:
	return _sent_state_props / maxf(1., _full_state_props)

func push_full_state(state: Dictionary) -> void:
	_full_state_props_accum += state.size()

func push_full_state_broadcast(state: Dictionary) -> void:
	_full_state_props_accum += state.size() * (multiplayer.get_peers().size() - 1)

func push_sent_state(state: Dictionary) -> void:
	_sent_state_props_accum += state.size()

func push_sent_state_broadcast(state: Dictionary) -> void:
	_sent_state_props_accum += state.size() * (multiplayer.get_peers().size() - 1)

func _ready() -> void:
	if not is_enabled():
		_logger.debug("Network performance disabled")
		return

	_logger.debug("Network performance enabled, registering performance monitors")
	Performance.add_custom_monitor(NETWORK_LOOP_DURATION_MONITOR, get_network_loop_duration_ms)
	Performance.add_custom_monitor(ROLLBACK_LOOP_DURATION_MONITOR, get_rollback_loop_duration_ms)
	Performance.add_custom_monitor(NETWORK_TICKS_MONITOR, get_network_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICKS_MONITOR, get_rollback_ticks)
	Performance.add_custom_monitor(ROLLBACK_TICK_DURATION_MONITOR, get_rollback_tick_duration_ms)
	Performance.add_custom_monitor(ROLLBACK_NODES_SIMULATED_MONITOR, get_rollback_nodes_simulated)
	Performance.add_custom_monitor(ROLLBACK_NODES_SIMULATED_PER_TICK_MONITOR, get_rollback_nodes_simulated_per_tick)
	
	Performance.add_custom_monitor(FULL_STATE_PROPERTIES_COUNT, get_full_state_props_count)
	Performance.add_custom_monitor(SENT_STATE_PROPERTIES_COUNT, get_sent_state_props_count)
	Performance.add_custom_monitor(SENT_STATE_PROPERTIES_RATIO, get_sent_state_props_ratio)
	
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.on_tick.connect(_on_network_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)
	
	NetworkRollback.before_loop.connect(_before_rollback_loop)
	NetworkRollback.on_process_tick.connect(_on_rollback_tick)
	NetworkRollback.after_loop.connect(_after_rollback_loop)

func _before_tick_loop() -> void:
	_network_loop_start = _time()
	_network_ticks_accum = 0

func _on_network_tick(_dt, _t) -> void:
	_network_ticks_accum += 1

func _after_tick_loop() -> void:
	_network_loop_duration = _time() - _network_loop_start
	_network_ticks = _network_ticks_accum
	
	_full_state_props = _full_state_props_accum
	_full_state_props_accum = 0
	
	_sent_state_props = _sent_state_props_accum
	_sent_state_props_accum = 0

func _before_rollback_loop() -> void:
	_rollback_loop_start = _time()
	_rollback_ticks_accum = 0
	_rollback_nodes_simulated_accum = 0

func _on_rollback_tick(_t: int) -> void:
	_rollback_ticks_accum += 1

func _after_rollback_loop() -> void:
	_rollback_loop_duration = _time() - _rollback_loop_start
	_rollback_ticks = _rollback_ticks_accum
	_rollback_nodes_simulated = _rollback_nodes_simulated_accum

func _time() -> float:
	return Time.get_unix_time_from_system()
