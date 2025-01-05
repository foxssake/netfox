extends StaticBody3D

@onready var parent: Node3D = get_parent()

var uid: int = 0
var current_marker: int = 0
var waypoints: Array[Vector3] = []

func _ready():
	waypoints = parent.waypoints

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
