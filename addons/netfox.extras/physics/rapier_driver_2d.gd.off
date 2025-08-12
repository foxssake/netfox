extends PhysicsDriver

class_name RapierDriver2D

func _init_physics_space() -> void:
	physics_space = get_viewport().world_2d.space
	PhysicsServer2D.space_set_active(physics_space, false)

func _physics_step(delta) -> void:
	RapierPhysicsServer2D.space_step(physics_space, delta)
	RapierPhysicsServer2D.space_flush_queries(physics_space)
	
func _snapshot_space(tick: int) -> void:
	snapshots[tick] = RapierPhysicsServer2D.export_binary(physics_space)

func _rollback_space(tick) -> void:
	if snapshots.has(tick):
		RapierPhysicsServer2D.import_binary(physics_space, snapshots[tick])
