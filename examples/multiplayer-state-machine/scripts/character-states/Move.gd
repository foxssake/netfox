extends RewindableState

@export var character: CharacterBody3D
@export var input: PlayerInputStateMachine
@export var speed = 5.0

func enter(_previous_state, _tick):
	character.color = Color.RED

func tick(delta, tick, is_fresh):
	var input_dir = input.movement
	var direction = (character.transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
	if direction:
		character.velocity.x = direction.x * speed
		character.velocity.z = direction.z * speed
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, speed)
		character.velocity.z = move_toward(character.velocity.z, 0, speed)

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
	character.velocity *= NetworkTime.physics_factor
	character.move_and_slide()
	character.velocity /= NetworkTime.physics_factor
	
	if input.jump:
		state_machine.transition(&"Jump")
	elif input_dir == Vector3.ZERO:
		state_machine.transition(&"Idle")
