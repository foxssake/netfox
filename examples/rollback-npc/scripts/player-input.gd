@tool
extends BaseNetInput

var movement: Vector3

func _get_rollback_input_properties() -> Array:
	return [
		"movement"
	]

func _gather():
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		0.0,
		Input.get_axis("move_north", "move_south")
	)
