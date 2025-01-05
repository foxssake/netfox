extends Node3D

var waypoints: Array[Vector3] = []

func _ready():
	waypoints = _generate_waypoints()

func _generate_waypoints() -> Array[Vector3]:
	var key_waypoints = [Vector3(3, 3, -13)]
	var current_position: Vector3 = key_waypoints[0]
	var left: bool = true
	var down: bool = false
	
	for i in range(12):
		if left:
			current_position.x = -13
			key_waypoints.append(current_position)
			down = true
			left = false
		elif down:
			current_position.z += 4
			key_waypoints.append(current_position)
			left = current_position.x != -13
			down = false
		else:
			current_position.x = 5
			key_waypoints.append(current_position)
			down = true
			left = false
			
	key_waypoints.append(Vector3(11, 3, 11))
	key_waypoints.append(Vector3(11, 3, -13))
	
	var complete_waypoints: Array[Vector3] = []

	for i in range(key_waypoints.size() - 1):
		var start = key_waypoints[i]
		var end = key_waypoints[i + 1]
		complete_waypoints.append(start)

		var direction = (end - start).normalized()
		var distance = start.distance_to(end)
		var steps = int(distance)

		for step in range(1, steps):
			var intermediate = start + direction * step
			complete_waypoints.append(intermediate)

	# Add the last waypoint
	complete_waypoints.append(key_waypoints[key_waypoints.size() - 1])

	return complete_waypoints
