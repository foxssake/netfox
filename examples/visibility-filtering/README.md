# Visibility filtering example

Demonstrates netfox's [visibility filtering] feature.

The level is split into two rooms, with a door connecting them in the middle.
While the hosting player sees everyone all the time, other players only receive
updates from players that they have *a clear line of sight* to. Players that
are invisible become transparent.

Note that this example doesn't try to be a full-fledged solution, but a small
demonstration of capability. This example does not provide a production-ready
solution.

Another limitation is that players might have line of sight to a hidden player
with their last known position, but not with their *actual* one. This means
that a player might fade in, but still not receive updates.


[visibility filtering]: https://foxssake.github.io/netfox/latest/netfox/guides/visibility-management/
