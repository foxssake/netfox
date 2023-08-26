extends Node3D
class_name Displaceable

var displace_buffer: Vector3 = Vector3.ZERO

func _ready():
	NetworkRollback.before_loop.connect(func(_t): displace_buffer = Vector3.ZERO)

func displace(speed: Vector3):
	displace_buffer += speed

func _tick(delta, _t):
	get_parent_node_3d().global_position += displace_buffer * delta
	displace_buffer = Vector3.ZERO
