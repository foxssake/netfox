extends VehicleBody3D

## Script example for server side coded tank.

@onready var input_sender : InputSender = $InputSender as InputSender
@onready var camera_3d : Camera3D = $Camera3D as Camera3D
@onready var tank_input : Node = $TankInput as Node

@export_category("Movement")
@export var engine_power := 600.0
@export var brake_force := 50.0
@export var max_steering_angle := 45.0
@export var steering_lerp_factor := 0.02

# Called when the node enters the scene tree for the first time.
func _ready():
	# Await so that player spawner sets our input authority.
	await get_tree().process_frame
	
	input_sender.process_authority()
	
	if input_sender.get_multiplayer_authority() == multiplayer.get_unique_id():
		camera_3d.current = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_input_sender_new_input_received(_tick : int):
	print("Server received new input!")
	print("movement:%s" %tank_input.movement)
	print("brake:%s" %tank_input.brake)
	if tank_input.movement.y != 0.0:
		if tank_input.movement.y < 0:
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
	steering = lerp(steering, deg_to_rad(max_steering_angle) * -tank_input.movement.x, steering_lerp_factor)


func _on_input_sender_input_missing(_current_tick : int, _latest_known_input_tick : int):
	print("Input is missing")
