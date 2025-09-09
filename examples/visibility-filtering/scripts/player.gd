@tool
extends CharacterBody3D

@export var speed := 4.0
@export var jump_velocity := 8.0
@export var input: Node

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func _get_rollback_state_properties() -> Array:
	return [
		"transform",
		"velocity"
	]

func _get_interpolated_properties() -> Array:
	return [
		"transform"
	]

func _ready():
	if Engine.is_editor_hint(): return

	if input == null:
		input = $Input

	position = Vector3(0, 4, 0)

	# Assign a random color
	var player_id := input.get_multiplayer_authority()
	var mesh := $MeshInstance3D as MeshInstance3D

	var color := Color.from_hsv((hash(player_id) % 256) / 256.0, 1.0, 1.0)
	var material := mesh.get_active_material(0) as StandardMaterial3D
	material = material.duplicate()
	material.albedo_color = color
	mesh.set_surface_override_material(0, material)

func _rollback_tick(dt, _tick, _is_fresh: bool):
	# Add gravity
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * dt

	var input_dir = input.movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Jump
	if input.is_jumping and is_on_floor():
		velocity.y = jump_velocity

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

