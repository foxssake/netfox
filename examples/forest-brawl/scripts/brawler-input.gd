extends BaseNetInput
class_name BrawlerInput

@export var switch_time: float = 1.0
var camera: Camera3D

@onready var _player: Node3D = get_parent()
@onready var _rollback_synchronizer: RollbackSynchronizer = _player.find_child("RollbackSynchronizer")
@onready var _confine_mouse: bool = DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CONFINED

var movement: Vector3 = Vector3.ZERO
var aim: Vector3 = Vector3.ZERO
var is_firing: bool = false

var confidence: float = 1.0

var _last_mouse_input: float = 0.0
var _aim_target: Vector3
var _projected_target: Vector3
var _has_aim: bool = false

static var _logger := _NetfoxLogger.new("game", "BrawlerInput")

func _ready():
	super()
	NetworkRollback.after_prepare_tick.connect(_predict)

func _input(event):
	if event is InputEventMouse:
		_last_mouse_input = NetworkTime.local_time

func _gather():
#	_logger.info("Gathering input")
	
	# Movement
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)
	
	# Aim
	aim = Vector3(
		Input.get_axis("aim_west", "aim_east"),
		0.0,
		Input.get_axis("aim_north", "aim_south")
	)
	
	if aim.length():
		# Prefer gamepad
		# Reset timeout for mouse motion
		_last_mouse_input = NetworkTime.local_time - switch_time
	elif NetworkTime.local_time - _last_mouse_input > switch_time:
		# Use movement if no mouse motion recently
		aim = movement
	elif _has_aim:
		# Use mouse raycast
		aim = (_aim_target - _player.global_position).normalized()
	else:
		# Fall back to mouse projected to player height
		aim = (_projected_target - _player.global_position).normalized()
	
	# Always aim horizontally, never up or down
	aim.y = 0
	aim = aim.normalized()
	
	# Hide mouse if inactive
	if NetworkTime.local_time - _last_mouse_input >= switch_time:
		DisplayServer.mouse_set_mode(
			DisplayServer.MOUSE_MODE_CONFINED_HIDDEN if _confine_mouse else DisplayServer.MOUSE_MODE_HIDDEN
		)
	else:
		DisplayServer.mouse_set_mode(
			DisplayServer.MOUSE_MODE_CONFINED if _confine_mouse else DisplayServer.MOUSE_MODE_VISIBLE
		)
	
	is_firing = Input.is_action_pressed("weapon_fire")

func _predict(_tick):
#	if is_multiplayer_authority():
#		confidence = 1.
#		# _logger.info("Predicted input with full confidence for rollback tick %d" % NetworkRollback.tick)
#		return
	
	if not _rollback_synchronizer:
		return
	
	if not _rollback_synchronizer.has_input():
		confidence = 0.
		return
	
	var input_age := _rollback_synchronizer.get_input_age()
	var max_predictable_age := 2 #NetworkTime.seconds_to_ticks(0.25)
	
	confidence = 1. - input_age / float(max_predictable_age)
	confidence = pow(confidence, 4.)
	confidence = clampf(confidence, 0., 1.)
	
#	_logger.info("Predicted input with confidence %.2f for rollback tick %d, with input age %d" % [confidence, NetworkRollback.tick, input_age])
	
	movement *= confidence
	aim *= confidence
	is_firing = is_firing and input_age == 0

func _physics_process(_delta):
	if not camera:
		camera = get_viewport().get_camera_3d()

	# Aim
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	var ray_length = 128

	var space = camera.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(
		ray_origin, ray_origin + ray_normal * ray_length
	))

	if not hit.is_empty():
		# Aim at raycast hit
		_aim_target = hit.position
		_has_aim = true
	else:
		# Project to player's height
		var height_diff = _player.global_position.y - ray_origin.y
		_projected_target = ray_origin + ray_normal * (height_diff / ray_normal.y)
		_has_aim = false
