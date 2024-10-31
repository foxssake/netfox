# Multiplayer state machine example

A simple demo game, using [netfox]'s `RollbackSynchronizer` and
`NetworkedStateMachine` to implement a server-authorative model, while also
compensating for latency with client-side prediction.

To edit and/or run, open the Godot project in the repository root, and open the
scene in this directory.

Compare it with:
* [Example with netfox](../multiplayer-netfox)
* [Simple multiplayer example](../multiplayer-simple)
* [Single player example](../single-player)

[netfox]: addons/netfox
