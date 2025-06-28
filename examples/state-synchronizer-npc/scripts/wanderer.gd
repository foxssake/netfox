extends CharacterBody3D

@export var move_speed: float = 4.0
@export var acceleration_time: float = 0.15

@export var rest_time_min: float = 0.5
@export var rest_time_max: float = 2.0

@export var wander_dst_min: float = 2.0
@export var wander_dst_max: float = 4.0
@export var arrival_range: float = 1.0

@export var wander_bounds: Rect2

var _wander_target: Vector3
var _wander_timer: float

func _ready():
	NetworkTime.on_tick.connect(_tick)
	_reset_wander()

func _tick(dt: float, _t) -> void:
	if not is_multiplayer_authority():
		return

	var diff := _wander_target - position
	var dst := diff.length()
	var dir := diff.normalized()

	var target_velocity := velocity

	if dst < arrival_range:
		# We're at the target position, wait until rest time is up
		target_velocity = Vector3.ZERO
		_wander_timer -= dt
		
		if _wander_timer <= 0:
			_reset_wander()
	else:
		# We have places to be, go
		target_velocity = dir * move_speed

	velocity = velocity.move_toward(target_velocity, move_speed / acceleration_time * dt)
	if not velocity.is_zero_approx():
		# Look in the direction we're going
		look_at(position + velocity, Vector3.UP, true)
	
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _reset_wander() -> void:
	_wander_target = _generate_target()
	_wander_timer = randf_range(rest_time_min, rest_time_max)

func _generate_target() -> Vector3:
	for __ in range(16):
		var angle := randf() * TAU
		var distance := randf_range(wander_dst_min, wander_dst_max)
		var target := position + distance * Vector3(cos(angle), 0, sin(angle))
		
		if wander_bounds.has_point(Vector2(target.x, target.z)):
			return target

	return position
