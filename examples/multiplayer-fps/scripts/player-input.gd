extends Node
class_name PlayerInputFPS

@onready var camera: Camera3D = $"../Head/Camera3D"

var movement: Vector3 = Vector3.ZERO
var fire: bool = false
var jump: bool = false

func _ready():
	NetworkTime.before_tick_loop.connect(_gather)
	if is_multiplayer_authority():
		camera.current = true

func _gather():
	if not is_multiplayer_authority():
		return
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var mx = Input.get_axis("ui_left", "ui_right")
	var mz = Input.get_axis("ui_up", "ui_down")
	movement = Vector3(mx, 0, mz)

	jump = Input.is_action_pressed("move_jump")
	fire = Input.is_action_pressed("weapon_fire")
