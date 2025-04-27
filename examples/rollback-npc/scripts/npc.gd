@tool
extends CharacterBody3D

@export var speed: float = 2.0
@export var sensor_radius: float = 4.0
@export var min_radius: float = 1.5

@onready var label := $Label3D as Label3D
@onready var rbs := $RollbackSynchronizer as RollbackSynchronizer

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func _get_rollback_state_properties() -> Array:
	return [
		"position",
		"velocity"
	]

func _get_interpolated_properties() -> Array:
	return [
		"position"
	]

func _rollback_tick(dt, _tick, _is_fresh: bool):
	label.text = "pre" if rbs.is_predicting() else "sim"

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

	velocity.x = move_toward(velocity.x, target_motion.x, speed / 0.35 * dt)
	velocity.z = move_toward(velocity.z, target_motion.z, speed / 0.35 * dt)

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _find_nearby_player() -> Node3D:
	var players := get_tree().get_nodes_in_group(&"Players")
	if players.is_empty():
		return null

	var sensor_radius_squared := pow(sensor_radius, 2.0)
	var min_radius_squared := pow(min_radius, 2.0)

	var closest_player: Node3D = null
	var closest_distance := INF
	for player in players:
		var distance := global_position.distance_squared_to(player.global_position)

		if distance >= sensor_radius_squared or distance <= min_radius_squared:
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_player = player

	return closest_player

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity
