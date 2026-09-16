extends BaseNetInput
class_name JobQueuePlayerInput

@export var mouse_sensitivity: float = 1.0

var override_mouse: bool = false
var mouse_movement: Vector2 = Vector2.ZERO

# Synced properties
var cursor_position: Vector2 = Vector2.ZERO
var clicked: bool = false

func _notification(what):
	if what == NOTIFICATION_READY:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		override_mouse = false
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		override_mouse = false
		
func _input(event: InputEvent):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		mouse_movement += event.relative * mouse_sensitivity
		
	if event.is_action_pressed("escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		override_mouse = true

func _gather():
	if not is_multiplayer_authority(): return
	
	if !clicked and Input.is_action_pressed("mouse_weapon_fire"):
		clicked = true
	else:
		clicked = false
	
	if !override_mouse:
		cursor_position += mouse_movement
	
	mouse_movement = Vector2.ZERO
