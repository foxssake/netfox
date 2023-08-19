extends Node3D
class_name FollowingCamera

@export var distance: float = 4.0
@export var approach_time: float = 0.125
@export var target: Node3D

func _physics_process(delta):
	if not target:
		return

	var desired_pos = target.global_position
	desired_pos += transform.basis.z * distance
	
	var diff = desired_pos - global_position
	var dst = diff.length()
	diff = diff.normalized()
	
	global_position = global_position.move_toward(desired_pos, dst / approach_time * delta)
