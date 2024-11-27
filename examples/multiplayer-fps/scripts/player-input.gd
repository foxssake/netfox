extends BaseNetInput
class_name PlayerInputFPS

@export var mouse_sensitivity: float = 1.0
@export var big_gun: MeshInstance3D

@onready var camera: Camera3D = $"../Head/Camera3D"

# Config variables
var is_setup: bool = false
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
		mouse_rotation.y = event.relative.x * mouse_sensitivity
		mouse_rotation.x = event.relative.y * mouse_sensitivity
		
	if event.is_action_pressed("escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		override_mouse = true
		
func _gather():
	if !is_setup:
		setup()
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var mx = Input.get_axis("move_west", "move_east")
	var mz = Input.get_axis("move_north", "move_south")
	movement = Vector3(mx, 0, mz)

	jump = Input.is_action_pressed("move_jump")
	fire = Input.is_action_pressed("weapon_fire")
	
	if override_mouse:
		look_angle = Vector2.ZERO
		mouse_rotation = Vector2.ZERO
	else:
		var delta: float = 1.0 / NetworkTime.tickrate
		look_angle = Vector2(-mouse_rotation.y * delta, -mouse_rotation.x * delta)
		mouse_rotation = Vector2.ZERO

func setup():
	is_setup = true
	camera.current = true
	big_gun.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
