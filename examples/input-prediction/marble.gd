extends CharacterBody3D

@export var acceleration: float = 16.
@export var jump_strength: float = 8.

@onready var _rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var input := $Input as Node

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	position = Vector3(0, 4, 0)

func _rollback_tick(dt, _t, _if):
	if is_zero_approx(input.confidence):
		_rollback_synchronizer.ignore(self)
	
	_force_update()
	if is_on_floor():
		velocity.y = input.movement.y * jump_strength
	else:
		velocity.y -= gravity * dt
	
	var movement = (input.movement * input.confidence) as Vector3
	movement.y = 0.
	
	if movement.is_zero_approx():
		var dv := velocity
		dv.y = 0.
		dv = dv.normalized() * acceleration * dt

		if dv.length_squared() > velocity.length_squared():
			dv = velocity
		velocity -= dv
	else:
		velocity += movement.normalized() * acceleration * dt
		
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
	# Face velocity
	var look = velocity.normalized()
	if not look.is_zero_approx() and abs(look.y) < .95:
		look_at_from_position(position, position + look)

func _force_update():
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
