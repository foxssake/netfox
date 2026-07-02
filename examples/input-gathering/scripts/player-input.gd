extends BaseNetInput

var movement: Vector3 = Vector3.ZERO
var is_jumping: bool = false

var _movement_buffer: Vector3 = Vector3.ZERO
var _movement_samples: int = 0

var _is_jumping_buffer: bool = false

func _ready():
	super()
	NetworkTime.after_tick.connect(func(_dt, _t): _gather_always())

func _process(_dt: float) -> void:
	_movement_buffer += Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)
	_movement_samples += 1

	if Input.is_action_just_pressed("move_jump"):
		_is_jumping_buffer = true

func _gather() -> void:
	# Average movement samples
	if _movement_samples > 0:
		movement = _movement_buffer / _movement_samples
	else:
		movement = Vector3.ZERO

	# Reset buffer
	_movement_buffer = Vector3.ZERO
	_movement_samples = 0

func _gather_always():
	# Jumping
	is_jumping = _is_jumping_buffer
	_is_jumping_buffer = false
