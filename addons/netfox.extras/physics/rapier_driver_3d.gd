extends PhysicsDriver

class_name RapierDriver3D

func _init_physics_space() -> void:
	physics_space = get_viewport().world_3d.space
	PhysicsServer3D.space_set_active(physics_space, false)

func _physics_step(delta) -> void:
	RapierPhysicsServer3D.space_step(physics_space, delta)
	RapierPhysicsServer3D.space_flush_queries(physics_space)
	
func _snapshot_space(tick: int) -> void:
	snapshots[tick] = RapierPhysicsServer3D.export_binary(physics_space)

func _rollback_space(tick) -> void:
	if snapshots.has(tick):
		RapierPhysicsServer3D.import_binary(physics_space, snapshots[tick])
