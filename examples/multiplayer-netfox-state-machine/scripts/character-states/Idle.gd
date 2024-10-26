extends NetworkedState

@export var character: CharacterBody3D
@export var move_state: NetworkedState
@export var jump_state: NetworkedState
@export var input: PlayerInputStateMachine

func enter():
	character.set_color(Color.WHITE)

func update(delta, tick, is_fresh):
	if input.movement != Vector3.ZERO:
		state_machine.set_state(move_state)
	elif input.jump:
		state_machine.set_state(jump_state)
