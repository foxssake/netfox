# Using RollbackSynchronizer without inputs

In certain cases, a component needs to participate in rollback, but is not
driven by any input. One example could be more complex NPCs. These need to be
part of the rollback tick loop, but they are not controlled by any player.

In these cases, you can use RollbackSynchronizer as described earlier in
[Responsive player movement], but without the input. This means not needing an
input node, and not configuring any input properties. State properties still
need to be configured, and the gameplay logic must be implemented in
`_rollback_tick()`.

!!!tip
    An example project featuring a simple NPC using an inputless
    RollbackSynchronizer can be found at [examples/rollback-npc].

Under the hood, *netfox* will simulate these inputless nodes whenever it
encounters a tick that has no state for the inputless node. On the server, this
means inputless nodes will be simulated only for new ticks. On clients, this
means never being simulated, since all state is received from the server. If
prediction is enabled, clients will simulate inputless nodes for ticks they
don't have data from the server.


[Responsive player movement]: ./responsive-player-movement.md
[examples/rollback-npc]: https://github.com/foxssake/netfox/tree/main/examples/rollback-npc
