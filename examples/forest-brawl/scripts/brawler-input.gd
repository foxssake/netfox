extends Node
class_name BrawlerInput

var camera: Camera3D
var movement: Vector3 = Vector3.ZERO
var aim: Vector3 = Vector3.ZERO

@onready var _player: Node3D = get_parent()
var _aim_target: Vector3
var _has_aim: bool = false

func _ready():
	# Gather input before sim loop
	# TODO: Doc how this is important, NetworkRollback events don't work here
	# TODO: Base class for input scripts?
	NetworkTime.before_tick_loop.connect(_gather)

func _gather():
	if not is_multiplayer_authority():
		return
	
	# Movement
	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		Input.get_action_strength("move_jump"),
		Input.get_axis("move_north", "move_south")
	)
	
	# Aim
	if _has_aim:
		aim = (_aim_target - _player.global_position).normalized()
	else:
		aim = Vector3.ZERO

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
	
	# print("[ray] %s -> %s: %s" % [ray_origin, ray_normal, hit])

	if not hit.is_empty():
		_aim_target = hit.position
		_aim_target.y = round(_aim_target.y - _player.position.y) + _player.position.y
		_has_aim = true
	else:
		_has_aim = false
