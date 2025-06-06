extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity: float = 4.5
@export var input: ExampleInputGathering.PlayerInput

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func _ready():
	position = Vector3(0, 4, 0)
	
	if input == null:
		input = $Input

func _rollback_tick(delta, _tick, _is_fresh):
	_force_update_is_on_floor()

	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Movement
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
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
