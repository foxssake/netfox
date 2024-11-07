extends AnimatableBody3D
class_name MovingPlatform

@export var speed: float = 2.
@onready var _origin: Vector3 = global_position
@onready var _target: Vector3 = $Target.global_position
@onready var _distance: float = _origin.distance_to(_target)
var _velocity: Vector3 = Vector3.ZERO

func get_velocity() -> Vector3:
	return _velocity

func _ready():
	NetworkRollback.on_prepare_tick.connect(_apply_tick)

func _apply_tick(tick: int):
	var previous_position = _get_position_for_tick(tick - 1)
	global_position = _get_position_for_tick(tick)
	
	_velocity = (global_position - previous_position) / NetworkTime.ticktime

func _get_position_for_tick(tick: int):
	var distance_moved = NetworkTime.ticks_to_seconds(tick) * speed
	var progress = distance_moved / _distance
	progress = pingpong(progress, 1)
	
	return _origin.lerp(_target, progress)
