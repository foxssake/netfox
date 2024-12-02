extends CharacterBody3D

@export var max_speed: float = 16.
@export var acceleration: float = 16.

@onready var _rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var input := $Input as Node

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_velocity: Vector3 = Vector3.ZERO
var gravity_velocity: Vector3 = Vector3.ZERO

func _ready():
	position = Vector3(0, 4, 0)

func _rollback_tick(dt, tick, is_fresh):
	if _rollback_synchronizer.is_predicting():
		# Don't predict input at all
		_rollback_synchronizer.ignore(self)
		return
	
	_force_update()
	
	if is_on_floor():
		gravity_velocity = Vector3.ZERO
	else:
		gravity_velocity += gravity * dt * Vector3.DOWN
	
	var movement = input.movement as Vector3
	movement.y = 0.

	var target_velocity = movement.normalized() * max_speed
	move_velocity = move_velocity.move_toward(target_velocity, acceleration * dt)
	
	velocity = gravity_velocity + move_velocity
	
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
#	var collision := move_and_collide(velocity * dt)
#	if collision:
#		var normal = collision.get_normal()
#		velocity = velocity.bounce(normal) * .2
#		move_velocity = velocity - gravity_velocity

func _force_update():
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
