extends BaseNetInput

## ServerSideTank input script

var movement: Vector2 = Vector2.ZERO
var brake : bool = false

func _gather():
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var mx = Input.get_axis("move_west", "move_east")
	var mz = Input.get_axis("move_north", "move_south")
	movement = Vector2(mx, mz)
	brake = Input.is_action_pressed("move_jump")
