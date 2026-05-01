extends BaseNetInput

## ServerSideTank input script

var movement: Vector2 = Vector2.ZERO
var brake : bool = false
var mouse_movement := Vector2.ZERO

var _mouse_movement_buffer := Vector2.ZERO

func _gather():
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var mx = Input.get_axis("move_west", "move_east")
	var mz = Input.get_axis("move_north", "move_south")
	movement = Vector2(mx, mz)
	brake = Input.is_action_pressed("move_jump")
	
	mouse_movement = _mouse_movement_buffer if _mouse_movement_buffer else Vector2.ZERO
	_mouse_movement_buffer = Vector2.ZERO

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	
	if event.is_action_pressed("escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_mouse_movement_buffer.x += event.relative.x
		_mouse_movement_buffer.y += event.relative.y
