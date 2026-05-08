extends VehicleBody3D

## Script example for server side coded tank.

@export_category("movement")
@export var engine_power := 450.0
@export var brake_force := 45.0
@export var max_steering_angle := 75.0
@export var steering_lerp_factor := 0.05
@export_category("turret_settings")
@export var turret : Node3D
@export var traverse_speed := 0.0004
@export var tilt_speed := 0.0001
@export var tilt_lower_limit := -30.0
@export var tilt_upper_limit := 30.0
@export var shell_spawn_point : Marker3D = null
@export var shell_scene : PackedScene = null
@export var fire_cooldown_tick : int = 180
@export_category("camera")
@export var regular_camera : Camera3D = null
@export var focus_camera : Camera3D = null
@export_category("ui")
@export var info_panel_scene : PackedScene = null

@onready var input_sender : InputSender = $InputSender as InputSender
@onready var tank_input : Node = $TankInput as Node

var score := 0

@onready var _turret_default_transform : Transform3D = self.turret.transform
var _turret_traverse := 0.0 # yaw
var _turret_tilt := 0.0 # pitch
var _last_fire_tick := 0


# Called when the node enters the scene tree for the first time.
func _ready():
	_last_fire_tick = NetworkTime.tick
	if tank_input.get_multiplayer_authority() == multiplayer.get_unique_id():
		if info_panel_scene:
			var panel := info_panel_scene.instantiate()
			add_child(panel)
		print("Setting camera true on %s" %[name])
		regular_camera.current = true

func _unhandled_input(event):
	# Dont process local inputs on other players tanks
	if not tank_input.is_multiplayer_authority():
		return
	
	if Input.is_action_just_pressed("weapon_fire"):
		# Dont fire on host machine as it will fire already on _on_input_sender_new_input_received
		if not multiplayer.is_server():
			_fire(NetworkTime.tick)
	
	if event.is_action_pressed("focus"):
		if focus_camera.current:
			focus_camera.current = false
			regular_camera.current = true
		else:
			regular_camera.current = false
			focus_camera.current = true

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

func _fire(tick : int) -> void:
	if tick - _last_fire_tick < fire_cooldown_tick:
		return
	
	print("Firing!")
	_last_fire_tick = tick
	var shell := shell_scene.instantiate() as Node3D
	get_tree().root.add_child(shell)
	shell.global_transform = shell_spawn_point.global_transform
	shell.firing_tank = self

# Called only on server.
func die() -> void:
	if not is_multiplayer_authority():
		return
	
	var player_spawner = get_parent()
	global_position = player_spawner.get_random_spawn_point()
	_turret_tilt = 0
	_turret_traverse = 0

func _on_input_sender_local_input(_tick):
	print("Input sender local input is emitted on peer:%s" %multiplayer.get_unique_id())


func _on_input_sender_missing_input(current_tick, latest_known_input_tick):
	print("Input is missing on :%s" %name)


func _on_input_sender_network_input(tick):
	_handle_movement(tank_input.movement)
	_move_turret(tank_input.mouse_movement)
	
	if tank_input.fire:
		_fire(tick)
