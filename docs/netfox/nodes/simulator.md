# Simulator

!!!warning
    Simulator is *experimental*, meaning the API may change in breaking ways,
    and may be less stable than other features.

    *Simulator* is also a work in progress name, we couldn't find a better one
    yet. Suggestions are welcome!

Simulates network logic depending on network authority. The host runs the
simulation one tick per tick and broadcasts the ground truth, the player owning
the input predicts it locally, everyone else shows the truth.

*Simulator* is an alternative to [RollbackSynchronizer]: the host never
rewinds or re-simulates, and only the local player is predicted. See
[Simulation] on how it works, and when to use which.

## Configuring state and input

To use *Simulator*, add it as a child to the target node, next to an
[InputSender], and configure it:

*Root* is the root node for resolving node paths in properties. Defaults to
the parent node.

*Listened input sender* is the [InputSender] whose inputs drive the
simulation. *Simulator* needs it assigned to work at all.

*State properties* define the game state. State properties are recorded for
each tick. When the host broadcasts the truth, *Simulator* accepts it as the
true state and applies it. Make sure that nodes containing state properties
are owned by the host.

Input properties are configured on the [InputSender].

See [Property paths] on how to specify properties.

!!!warning
    It is not recommended to have both state and input properties on the same
    node. Nodes with state belong to the host, and nodes with input belong to
    the player.

## Writing simulated scripts

During setup, *Simulator* finds all nodes under *root* that implement
`_simulated_tick`, and calls them every time a tick is simulated.

Simulating works the same way as rollback. For tick T, the inputs of tick T are
applied, then `_simulated_tick(delta, T, is_fresh)` is called, and the
resulting state is recorded as the state of tick T + 1:

```gdscript
extends CharacterBody3D

@export var speed: float = 4.0
@export var input: PlayerInput

func _simulated_tick(delta: float, tick: int, is_fresh: bool) -> void:
  # Inputs of tick are applied here, the state you leave behind
  # is the state of tick + 1
  velocity = input.movement.normalized() * speed

  velocity *= NetworkTime.physics_factor
  move_and_slide()
  velocity /= NetworkTime.physics_factor
```

Note the usage of `physics_factor` - this is explained in [Rollback caveats].

## Peers

*Simulator* works in one of three ways, depending on authority:

*Host* - *Simulator* has authority, the input belongs to some other peer, or to
the host itself. The host runs `_simulated_tick` at its current tick with the
inputs received by [InputSender], then broadcasts the ground truth. If the
inputs of the tick didn't arrive in time, they're predicted, see
[InputSender](./input-sender.md#predicting-and-merging-inputs).

*Authoritative peer* - the input belongs to the local peer, this is your
player. *Simulator* applies the latest truth received from the host, then
re-runs `_simulated_tick` with fresh local inputs, up to the current tick plus
the [input lead](../guides/simulation.md#input-lead).

*Puppet peer* - neither *Simulator* nor the input has authority, this is how
you see remote players. *Simulator* only applies the truth received from the
host. We simply don't know their future inputs, so there's nothing to
re-simulate.

## Single fire events

`is_fresh` is true the first time a tick is simulated. Authoritative peers
simulate the same tick again after receiving the truth from the host, with
`is_fresh` false. Use it for effects like sounds that should play once.

## Schemas

Use `set_schema()` to pick serializers for state properties, and lower
bandwidth. The schema must be the same on every peer:

```gdscript
simulator.set_schema({
  ":global_transform": NetworkSchemas.transform3f32(),
  ":velocity": NetworkSchemas.vec3f32()
})
```

Input properties get their schema on the [InputSender]. See [Network schemas]
for more.

## Changing configuration

*Simulator* has to do some setup work whenever the state properties change.
Call `process_settings()` after any change to configuration, or use
`add_state()`, which updates settings automatically.

Changing or assigning the *listened input sender* during runtime is not
recommended, but also requires a call to `process_settings()`.

## Changing ownership

Whenever the authority of the [InputSender]'s input nodes changes, call
`process_authority()`. Make sure to do this at the same time on all peers.

## Visibility

*Simulator* has a `visibility_filter` that decides which peers will receive
updates. See [Visibility management].

[RollbackSynchronizer]: ./rollback-synchronizer.md
[InputSender]: ./input-sender.md
[Simulation]: ../guides/simulation.md
[Property paths]: ../guides/property-paths.md
[Network schemas]: ../guides/network-schemas.md
[Visibility management]: ../guides/visibility-management.md
[Rollback caveats]: ../tutorials/rollback-caveats.md
