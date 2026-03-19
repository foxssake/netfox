
extends PhysicsDriver

class_name RapierDriver2D

var _state: StateManager2D

var _stored_states: int = 0


func _init_physics_space() -> void:
	physics_space = get_viewport().world_2d.space
	PhysicsServer2D.space_set_active(physics_space, false)

	_state = StateManager2D.new()
	_state.root_node = self
	_state.set_max_cache_length(ProjectSettings.get_setting("netfox/rollback/history_limit", 64))
	_state.set_rolling_cache(true)
	add_child(_state)


func _physics_step(delta) -> void:
	RapierPhysicsServer2D.space_step(physics_space, delta)
	RapierPhysicsServer2D.space_flush_queries(physics_space)


func _snapshot_space(tick: int) -> void:
	_state.cache_state(physics_space, tick)


func _rollback_space(tick: int) -> void:
	# With rolling cache, tick states are ordered by age with the newest at 0
	var offset = NetworkTime.tick - tick
	if (offset >= _stored_states):
		return

	_stored_states = min(_stored_states + 1, _state.max_cache_length)
	_state.load_cached_state(physics_space, offset)
