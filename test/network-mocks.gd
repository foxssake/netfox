extends Object
class_name NetworkMocks

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
