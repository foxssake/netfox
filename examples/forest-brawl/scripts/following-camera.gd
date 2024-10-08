extends Camera3D
class_name FollowingCamera

@export var distance: float = 16
@export var approach_time: float = 0.125
@export var target: Node3D

func _ready():
	NetworkTime.on_tick.connect(_tick)

func _tick(delta: float, _t: int):
	if not target:
		return

	var desired_pos: Vector3 = target.global_position
	desired_pos += transform.basis.z * distance
	
	var diff: Vector3 = desired_pos - global_position
	var dst: float = diff.length()
	diff = diff.normalized()
	
	global_position += diff * minf(dst / approach_time * delta, dst)
