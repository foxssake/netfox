# RewindableStateMachine

Rollback-aware state machine implementation.

State machines are often used in games to implement different behaviors.
However, most implementations are not prepared for rollbacks. This class
provides an extensible implementation that can be used alongside a
[RollbackSynchronizer].

For a full example, see [multiplayer-state-machine].

## Creating a state machine

The first step is to add the RewindableStateMachine to your scene. It also
requires a RollbackSynchronizer that manages its `state` property. Unless these
conditions are satisfied, an editor warning will be displayed.

> Note: Editor warnings are only updated when the node tree changes,
> configuration changes don't trigger an update. You may need to reload the
> scene after fixing a warning.

![RewindableStateMachine with
RollbackSynchronizer](../assets/rewindable-state-machine-rollback.png)

Notice the RollbackSynchronizer added as a sibling to the
RewindableStateMachine, and having its `state` property configured.

## Implementing states

States are where the custom gameplay logic can be implemented. Each state must
be an extension of the RewindableState class, and added as a child to the
RewindableStateMachine.

States react to the game world using the following callbacks:

* `tick(delta, tick, is_fresh)` is called for every rollback tick.
* `enter(previous_state, tick)` is called when entering the state.
* `exit(next_state, tick)` is called when exiting the state.
* `can_enter(previous_state)` is called before entering the state. The state is
  only entered if this method returns true.

You can override any of these callbacks to implement your custom behaviors.

For example, the snippet below implements an idle state, that transitions to
other states based on movement inputs:

```gdscript
extends RewindableState

@export var input: PlayerInputStateMachine

func tick(delta, tick, is_fresh):
	if input.movement != Vector3.ZERO:
		state_machine.transition(&"Move")
	elif input.jump:
		state_machine.transition(&"Jump")

```

Transitions are based on *node names*, i.e. calling `transition(&"Move")` will
transition to a state node called *Move*. 

![RewindableStates under a state
machine](../assets/rewindable-state-children.png)

States must be added as children under a RewindableStateMachine to work.

[multiplayer-state-machine]: https://github.com/foxssake/netfox/tree/main/examples/multiplayer-state-machine
[RollbackSynchronizer]: ../../netfox/nodes/rollback-synchronizer.md
