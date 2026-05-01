extends VehicleBody3D

## Script example for server side coded tank.

@export_category("movement")
@export var engine_power := 600.0
@export var brake_force := 50.0
@export var max_steering_angle := 45.0
@export var steering_lerp_factor := 0.02
@export_category("turret_settings")
@export var turret : Node3D
@export var traverse_speed := 0.0001
@export var tilt_speed := 0.0001
@export var tilt_lower_limit := -30.0
@export var tilt_upper_limit := 30.0
@export_category("camera")
@export var camera_3d : Camera3D

@onready var input_sender : InputSender = $InputSender as InputSender
@onready var tank_input : Node = $TankInput as Node
var logger := NetfoxLogger._for_netfox("ServerTank")

@onready var _turret_default_transform : Transform3D = self.turret.transform
var _turret_traverse := 0.0 # yaw
var _turret_tilt := 0.0 # pitch


# Called when the node enters the scene tree for the first time.
func _ready():
	# Await so that player spawner sets our input authority.
	await get_tree().process_frame
	
	input_sender.process_authority()
	
	if tank_input.get_multiplayer_authority() == multiplayer.get_unique_id():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		camera_3d.current = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_input_sender_new_input_received(_tick : int):
	logger.trace("On received input movement:%s, brake:%s", [tank_input.movement, tank_input.brake])
	_handle_movement(tank_input.movement)
	_move_turret(tank_input.mouse_movement)

# Moves vehicle on hosts.
func _handle_movement(movement : Vector2) -> void:
	if not is_multiplayer_authority():
		return
	
	if movement.y != 0.0:
		if movement.y < 0:
			engine_force = engine_power
		else:
			engine_force = -engine_power
		
	else:
		# No move input
		engine_force = 0
	
	# Brake
	if tank_input.brake:
		brake = brake_force
	else:
		brake = 0.0
	
	# Steering
	steering = lerp(steering, deg_to_rad(max_steering_angle) * -movement.x, steering_lerp_factor)

func _on_input_sender_input_missing(_current_tick : int, _latest_known_input_tick : int):
	print("Input is missing")

# Moves the turret on the host.
func _move_turret(mouse_input : Vector2) -> void:
	# Return if not host.
	if not is_multiplayer_authority():
		return
	
	_turret_traverse -= mouse_input.x * traverse_speed
	_turret_tilt += mouse_input.y * tilt_speed
	
	turret.basis = _turret_default_transform.basis
	turret.basis = turret.basis.rotated(Vector3.UP, _turret_traverse)

	_turret_tilt = clamp(_turret_tilt, deg_to_rad(tilt_lower_limit), deg_to_rad(tilt_upper_limit))
	turret.basis = turret.basis.rotated(turret.basis.x, _turret_tilt)
