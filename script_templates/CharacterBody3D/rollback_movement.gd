# meta-name: Netcode Movement
# meta-description: Basic predefined movement for rollback netcode

extends _BASE_

@export var speed = 5.0
@export var input: Node

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func _ready() -> void:
	if input == null:
		input = $Input

func _rollback_tick(dt: float, _tick: int, _is_fresh: bool) -> void:
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
