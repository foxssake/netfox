extends Node3D

# Tank Shell script

# Only can kill tanks on server.

@export var speed := 50.0

# Set this from firing tank
var firing_tank : Node = null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position += global_transform.basis.z * speed * delta

func _on_area_3d_body_entered(body):
	if multiplayer.is_server():
		if body.has_method("die"):
			body.die()
			if firing_tank:
				print("%s killed another tank +1 score!" %firing_tank.name)
				firing_tank.score += 1
	
	
	queue_free()
