extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var input: BrawlerInput

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	if not input:
		input = $Input

	position = Vector3(0, 4, 0)

	# TODO: What if the RollbackSynchronizer had a flag for this?
	await get_tree().process_frame
	$RollbackSynchronizer.process_settings()

func _tick(delta, _t):
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
		transform = transform.looking_at(position + Vector3(input.aim.x, 0, input.aim.z), Vector3.UP, true)

	# Apply movement
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
