extends Node3D
class_name Displaceable

@export var mass: float = 1.0
var impulse: Vector3 = Vector3.ZERO

func displace(speed: Vector3):
	impulse += speed

func _rollback_tick(delta, _t, _if):
	var parent = get_parent_node_3d()
	var offset = impulse * delta / mass
	if parent is CharacterBody3D:
		parent.move_and_collide(offset)
	else:
		parent.global_position += offset
	impulse = impulse.move_toward(Vector3.ZERO, impulse.length() * mass * delta)
