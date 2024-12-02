extends CharacterBody3D

@export var max_speed: float = 16.
@export var acceleration: float = 16.
@export var jump_strength: float = 8.

@onready var _rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var input := $Input as Node

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	position = Vector3(0, 4, 0)
	
	var player_id := input.get_multiplayer_authority()
	var mesh := $MeshInstance3D as MeshInstance3D
	var material := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = Color.from_hsv((player_id % 256) / 256.0, 1.0, 1.0)
	mesh.set_surface_override_material(0, material)

func _rollback_tick(dt, _t, _if):
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
		var accel = movement.z * acceleration * dt
		var steer = movement.x * clampf(velocity.length(), 0., acceleration) * 4. * dt
		
		velocity += accel * transform.basis.z + steer * transform.basis.x
		if velocity.length() > max_speed:
			# TODO: This includes gravity too
			velocity = velocity.normalized() * max_speed
		
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
