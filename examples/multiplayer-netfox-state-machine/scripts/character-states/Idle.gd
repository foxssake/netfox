extends NetworkedState

@export var character: CharacterBody3D
@export var input: PlayerInputStateMachine

func enter(_previous_state, _tick):
	character.set_color(Color.WHITE)

func update(delta, tick, is_fresh):
	character.velocity *= NetworkTime.physics_factor
	character.move_and_slide()
	character.velocity /= NetworkTime.physics_factor
	
	if input.movement != Vector3.ZERO:
		state_machine.set_state(&"Move")
	elif input.jump:
		state_machine.set_state(&"Jump")
