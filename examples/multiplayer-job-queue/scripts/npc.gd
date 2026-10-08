extends StaticBody3D

@onready var parent: Node3D = get_parent()

var waypoints: Array[Vector3] = []
var waypoint_count: int
var current_waypoint: int = 0
var target_waypoint: int = 0
var uid: int = 0

func _ready():
	waypoints = parent.waypoints
	waypoint_count = waypoints.size()
	target_waypoint = waypoint_count - 24

	# Physically place NPC at the first waypoint if it exists
	if waypoint_count > 0:
		global_position = waypoints[0]

func _physics_process(delta: float) -> void:
	if waypoint_count <= 1:
		return  # No path or just one point, do nothing

	# 1) Get the NPC's queue position each frame
	var queue_position = parent.get_queue_position(uid)

	# 2) Convert that 'queue position' into a target waypoint index
	#    If queue_position is a "reverse index" (1=last, 2=second-last, etc.):
	var target_waypoint_index = target_waypoint - queue_position

	# 3) Clamp to avoid out of range
	if target_waypoint_index < 0:
		target_waypoint_index = 0
	elif target_waypoint_index >= waypoint_count:
		target_waypoint_index = waypoint_count - 1

	# 4) Check if we need to move forward, backward, or stand still
	if current_waypoint < target_waypoint_index:
		# Move forward along the path
		var next_waypoint_index = current_waypoint + 1

		# Keep it in range
		if next_waypoint_index >= waypoint_count:
			next_waypoint_index = waypoint_count - 1

		var marker = waypoints[next_waypoint_index]
		move_toward_waypoint(marker, delta)

		# If we're close to next waypoint, increment
		if global_position.distance_to(marker) < 0.2:
			current_waypoint = next_waypoint_index

	elif current_waypoint > target_waypoint_index:
		var prev_waypoint_index = current_waypoint - 1
		if prev_waypoint_index < 0:
			prev_waypoint_index = 0

		var marker = waypoints[prev_waypoint_index]
		move_toward_waypoint(marker, delta)

		if global_position.distance_to(marker) < 0.2:
			current_waypoint = prev_waypoint_index
	elif current_waypoint == waypoint_count - 1:
		queue_free()

func move_toward_waypoint(target: Vector3, delta: float) -> void:
	var direction = global_position.direction_to(target)
	# Move in X/Z plane, ignoring vertical
	global_position += Vector3(direction.x, 0, direction.z) * 10.0 * delta
	rotation.y = atan2(direction.x, direction.z)
