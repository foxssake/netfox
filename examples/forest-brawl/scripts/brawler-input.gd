extends BaseNetInput
class_name BrawlerInput

var camera: Camera3D
@onready var _player: Node3D = get_parent()

var movement: Vector3 = Vector3.ZERO
var aim: Vector3 = Vector3.ZERO
var is_firing: bool = false

var _aim_target: Vector3
var _has_aim: bool = false

func _gather():
	# Movement
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)
	
	# Aim
	# Prefer gamepad
	aim = Vector3(
		Input.get_axis("aim_west", "aim_east"),
		0.0,
		Input.get_axis("aim_north", "aim_south")
	)
	
	# Use mouse as fallback
	if aim.length() <= 0.1 and _has_aim:
		aim = (_aim_target - _player.global_position).normalized()
	
	is_firing = Input.is_action_pressed("weapon_fire")

func _physics_process(delta):
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
		_aim_target = hit.position
		_aim_target.y = round((_aim_target.y - _player.global_position.y) / 2) * 2 + _player.global_position.y
		_has_aim = true
	else:
		_has_aim = false
