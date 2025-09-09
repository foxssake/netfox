@tool
extends BaseNetInput

var movement: Vector3
var is_jumping: bool

func _get_rollback_input_properties() -> Array:
	return [
		"movement",
		"is_jumping"
	]

func _gather():
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		0.0,
		Input.get_axis("move_north", "move_south")
	)

	is_jumping = Input.is_action_pressed("move_jump")
