extends BaseNetInput

@export var mouse_sensitivity: float = 1.0
var override_mouse: bool = false

# Input variables
var mouse_rotation: Vector2 = Vector2.ZERO
var look_angle: Vector2 = Vector2.ZERO
var movement: Vector3 = Vector3.ZERO
var fire: bool = false
var jump: bool = false

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		override_mouse = false
		
func _input(event: InputEvent) -> void:
	if !is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		mouse_rotation.y += event.relative.x * mouse_sensitivity
		mouse_rotation.x += event.relative.y * mouse_sensitivity
		
	if event.is_action_pressed("escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		override_mouse = true

func _ready():
	super()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _gather():
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var mx = Input.get_axis("move_west", "move_east")
	var mz = Input.get_axis("move_north", "move_south")
	movement = Vector3(mx, 0, mz)

	jump = Input.is_action_pressed("move_jump")
	fire = Input.is_action_pressed("mouse_weapon_fire")
	
	if override_mouse:
		look_angle = Vector2.ZERO
		mouse_rotation = Vector2.ZERO
	else:
		look_angle = Vector2(-mouse_rotation.y, -mouse_rotation.x)
		mouse_rotation = Vector2.ZERO
