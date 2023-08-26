extends Node3D
class_name Displaceable

var displace_buffer: Vector3 = Vector3.ZERO

func _ready():
	# NetworkRollback.before_loop.connect(func(_t): displace_buffer = Vector3.ZERO)
	pass

func displace(speed: Vector3):
	displace_buffer += speed

func _tick(delta, _t):
	var parent = get_parent_node_3d()
	if parent is CharacterBody3D:
		parent.move_and_collide(displace_buffer * delta)
	else:
		parent.global_position += displace_buffer * delta
	displace_buffer = Vector3.ZERO
