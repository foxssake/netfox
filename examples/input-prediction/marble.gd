extends CharacterBody3D

@export var max_speed: float = 16.
@export var acceleration: float = 16.
@export var turn_degrees: float = 360.
@export var jump_strength: float = 8.

var is_reversing := false

@onready var _rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var input := $Input as Node

var gravity: float = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func _ready():
	position = Vector3(0, 4, 0)
	
	var player_id := input.get_multiplayer_authority()
	var mesh := $MeshInstance3D as MeshInstance3D
	var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = Color.from_hsv((player_id % 256) / 256.0, 1.0, 1.0)
	mesh.set_surface_override_material(0, material)

func _rollback_tick(dt, _t, _if):
	if is_zero_approx(input.confidence):
		# Can't predict, not enough confidence in input
		_rollback_synchronizer.ignore_prediction(self)
		return

	_force_update()

	if is_on_floor():
		velocity.y = input.movement.y * jump_strength
	else:
		velocity.y -= gravity * dt
	
	var movement := input.movement as Vector3
	movement.y = 0.
	
	var reverse_factor = 1.
	
	if is_on_floor():
		var accel := 0.
		var steer := 0.
		var brake := 0.
		
		var speed := velocity.length()
		
		if movement.is_zero_approx():
			# Brake
			brake = acceleration * 1. * dt
		else:
			if is_zero_approx(speed) and not is_zero_approx(movement.z):
				is_reversing = not is_reversing

			if is_reversing:
				movement.z *= -1.

			if movement.z > 0:
				accel = abs(movement.z) * acceleration * dt
			else:
				brake = abs(movement.z) * 2. * acceleration * dt

			steer = movement.x * turn_degrees
			steer *= pow(clampf(speed / max_speed, 0., 1.), .5)
		
		if is_reversing:
			reverse_factor = -1.
		
		brake = minf(brake, speed)
		velocity += accel * reverse_factor * transform.basis.z - velocity.normalized() * brake
		velocity = velocity.rotated(transform.basis.y, deg_to_rad(steer) * dt)
		
		if velocity.length() > max_speed:
			velocity = velocity.normalized() * max_speed
		
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
	# Face velocity
	var look = velocity.normalized() * reverse_factor
	if not look.is_zero_approx() and abs(look.y) < .95:
		look_at_from_position(position, position + look, transform.basis.y, true)

func _force_update():
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
