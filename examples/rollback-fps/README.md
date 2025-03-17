# Rollback FPS example

A demo FPS game, based on netfox's `RollbackSynchronizer` and
`RewindableAction`, to demonstrate how to create a server-authoritative
shooter.

Player stats and firing are handled from inside the [rollback tick loop],
taking advantage of the latency compensation provided by rollback.

To edit and/or run, open the Godot project in the repository root, and open the
scene in this directory.

[rollback tick loop]: https://foxssake.github.io/netfox/latest/netfox/guides/network-rollback/
