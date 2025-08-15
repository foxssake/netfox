extends Object
class_name NetworkMocks

static var NOOP = func(): pass

static func set_network_tick(p_tick: int) -> void:
	NetworkTime._tick = p_tick

static func set_rollback_tick(p_tick: int) -> void:
	NetworkRollback._tick = p_tick

static func set_tick(network_tick: int, rollback_tick: int) -> void:
	set_network_tick(network_tick)
	set_rollback_tick(rollback_tick)

static func in_rollback(callback: Callable) -> void:
	NetworkRollback._is_rollback = true
	callback.call()
	NetworkRollback._is_rollback = false

## Runs [param]callback[/param] in the network tick loop
static func in_network_tick_loop(callback: Callable) -> void:
	NetworkTime.before_tick_loop.emit()
	callback.call()
	NetworkTime.after_tick_loop.emit()

## Runs [param]callback[/param] as part of a network tick
static func in_network_tick(callback: Callable = NOOP) -> void:
	NetworkTime.before_tick.emit(NetworkTime.ticktime, NetworkTime.tick)
	NetworkTime.on_tick.emit(NetworkTime.ticktime, NetworkTime.tick)
	callback.call()
	NetworkTime.after_tick.emit(NetworkTime.ticktime, NetworkTime.tick)

	NetworkTime._tick += 1

## Runs a single network tick
static func run_network_tick() -> void:
	in_network_tick()
