extends BaseNetInput

var movement: Vector3 = Vector3.ZERO

var _movement_buffer: Vector3 = Vector3.ZERO
var _movement_samples: int = 0

func _process(_dt: float) -> void:
	_movement_buffer += Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)
	_movement_samples += 1

func _gather() -> void:
	# Average samples
	if _movement_samples > 0:
		movement = _movement_buffer / _movement_samples
	else:
		movement = Vector3.ZERO

	# Reset buffer
	_movement_buffer = Vector3.ZERO
	_movement_samples = 0
