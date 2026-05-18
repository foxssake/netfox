extends CharacterBody3D
class_name TakeoverPlayer

@export var move_speed := 6.
@onready var input := $Input as TakeoverPlayerInput
@onready var _logger := NetfoxLogger.new("to", "Player:" + name)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _rollback_tick(dt: float, _t: int, _if: bool) -> void:
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * dt

	var direction = (transform.basis * Vector3(input.movement.x, 0, input.movement.y)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
	if input.is_interacting:
		var mech := TakeoverMech.find_in_range(self)
		_logger.info("Taking over mech: %s", [mech])
		if mech != null:
			mech.take_over(self)

func _force_update_is_on_floor() -> void:
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
