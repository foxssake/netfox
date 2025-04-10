@tool
extends CharacterBody3D

@export var speed: float = 2.0
@export var sensor_radius: float = 4.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

var _sensor_shape := SphereShape3D.new()

func _get_rollback_state_properties() -> Array:
	return [
		"transform",
		"velocity"
	]

func _get_interpolated_properties() -> Array:
	return [
		"transform"
	]

func _rollback_tick(dt, _tick, _is_fresh: bool):
	# Add gravity
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * dt

	var target_motion := Vector3.ZERO
	var nearby_player := _find_nearby_player()
	if nearby_player:
		target_motion = nearby_player.global_position - global_position
		target_motion.y = 0.

		target_motion = target_motion.normalized() * speed

	velocity.x = move_toward(velocity.x, target_motion.x, speed / 0.15 * dt)
	velocity.z = move_toward(velocity.z, target_motion.z, speed / 0.15 * dt)

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _find_nearby_player() -> Node3D:
	var space := get_world_3d().direct_space_state
	_sensor_shape.radius = sensor_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 0x1 # Players should be on layer 1
	query.shape = _sensor_shape
	query.transform = global_transform

	var hits := space.intersect_shape(query)
	if hits.is_empty():
		return null

	return hits[0]["collider"] as Node3D

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity
