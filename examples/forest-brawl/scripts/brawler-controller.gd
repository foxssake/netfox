extends CharacterBody3D
class_name BrawlerController

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var input: BrawlerInput
@export var spawn_point: Vector3 = Vector3(0, 4, 0)
@export var death_depth: float = 4.0
@export var respawn_time: float = 4.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var respawn_tick: int = -1

func _ready():
	if not input:
		input = $Input

	position = spawn_point

	# TODO: What if the RollbackSynchronizer had a flag for this?
	await get_tree().process_frame
	$RollbackSynchronizer.process_settings()
	
	NetworkTime.on_tick.connect(_tick)

func _tick(delta, tick):
	if not NetworkRollback.is_rollback():
		if position.y < -death_depth and respawn_tick < tick:
			respawn_tick = tick + respawn_time * NetworkTime.tickrate
			print("Detected fall! Respawning on tick %s + %s -> %s" % [tick, respawn_time * NetworkTime.tickrate, respawn_tick])
	else:
		# Process respawn
		if tick == respawn_tick:
			position = spawn_point
			velocity = Vector3.ZERO

		# Add the gravity.
		if not is_on_floor():
			velocity.y -= gravity * delta

		# Jump
		if input.movement.y > 0 and is_on_floor():
			velocity.y = jump_velocity * input.movement.y

		# Movement
		var direction = Vector3(input.movement.x, 0, input.movement.z).normalized()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
		
		# Aim
		if input.aim:
			transform = transform.looking_at(position + Vector3(input.aim.x, 0, input.aim.z), Vector3.UP, true).scaled_local(scale)

		# Apply movement
		velocity *= NetworkTime.physics_factor
		move_and_slide()
		velocity /= NetworkTime.physics_factor
