extends StaticBody3D

var waypoints: Array[Vector3] = [Vector3(3, 3, -13)]
var current_marker: int = 0

func _ready():
	var current_position: Vector3 = waypoints[0]
	var left: bool = true
	var down: bool = false
	
	for i in range(12):
		if left:
			current_position.x = -13
			waypoints.append(current_position)
			down = true
			left = false
		elif down:
			current_position.z += 4
			waypoints.append(current_position)
			left = current_position.x != -13
			down = false
		else:
			current_position.x = 5
			waypoints.append(current_position)
			down = true
			left = false
			
	waypoints.append(Vector3(11, 3, 11))
	waypoints.append(Vector3(11, 3, -13))

func _physics_process(delta):
	if waypoints.size() == 0:
		return
		
	if current_marker >= waypoints.size():
		queue_free()
		return
		
	var marker = waypoints[current_marker]
	if global_position.is_equal_approx(marker):
		current_marker += 1
	global_position = lerp(global_position, marker, delta * 5)
