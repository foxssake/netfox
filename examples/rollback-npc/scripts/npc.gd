@tool
extends CharacterBody3D

@export var speed: float = 2.0
@export var sensor_radius: float = 4.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

var _last_simulated_tick := 0

static var _logger := _NetfoxLogger.new("npc", "npc")

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

#	_logger.info("Ran rollback tick, owner is %d", [get_multiplayer_authority()])

func _find_nearby_player() -> Node3D:
	var players := get_tree().get_nodes_in_group(&"Players")
	if players.is_empty():
		return null

	var closest_player: Node3D = null
	var closest_distance := INF
	for player in players:
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < closest_distance and distance < pow(sensor_radius, 2.0):
			closest_distance = distance
			closest_player = player

	return closest_player

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity
