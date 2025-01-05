extends StaticBody3D

@onready var parent: Node3D = get_parent()

var waypoint_count: int = 999
var current_waypoint: int = 999
var uid: int = 0
var waypoints: Array[Vector3] = []

func _ready():
	waypoints = parent.waypoints
	waypoint_count = waypoints.size()
	current_waypoint = waypoint_count - 1
	global_position = waypoints[0]

func _physics_process(delta):
	if waypoints.size() == 0:
		return
		
	if current_waypoint == 0:
		queue_free()
		return
	
	var queue_position = parent.get_queue_position(uid)
	if current_waypoint == queue_position:
		return
		
	var marker = waypoints[queue_position - current_waypoint]
	if global_position.distance_to(marker) < 0.1:
		current_waypoint -= 1
	
	var direction: Vector3 = global_position.direction_to(marker)
	global_position += Vector3(direction.x, 0, direction.z) * delta * 10
	rotation.y = atan2(direction.x, direction.z)
