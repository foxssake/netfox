extends RewindableState

@export var character: CharacterBody3D
@export var input: PlayerInputStateMachine
@export var speed = 5.0
@export var jump_strength = 5.0

# Only enter if the character is on the floor
func can_enter(_previous_state):
	return input.jump and character.is_on_floor()
	
func enter(_previous_state, _tick):
	character.set_color(Color.BLUE)
	character.velocity.y = jump_strength

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
	
	if character.is_on_floor():
		state_machine.transition(&"Idle")
