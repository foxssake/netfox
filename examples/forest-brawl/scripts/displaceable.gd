extends Node3D
class_name Displaceable

@export var mass: float = 1.0
var displace_buffer: Vector3 = Vector3.ZERO

func displace(speed: Vector3):
	displace_buffer += speed

func _rollback_tick(delta, _t, _if):
	var parent = get_parent_node_3d()
	var offset = displace_buffer * delta / mass
	if parent is CharacterBody3D:
		parent.move_and_collide(offset)
	else:
		parent.global_position += offset
	displace_buffer = Vector3.ZERO
