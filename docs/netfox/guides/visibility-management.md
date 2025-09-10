# Visibility Management

By default, *netfox* synchronizes all properties to all peers, broadcasting
data. This may not always be the best approach. An example is competitive
games. These games often features mechanics like fog of war, invisibility, or
line of sight checks. If any of these obscures a player, other players should
not receive information about them, to avoid the possibility of wallhacks and
other similar cheats.

This is supported by the use of *visibility filters*. They provide three
mechanisms to determine who should receive data and who shouldn't.

## Accessing the visibility filter

Both [RollbackSynchronizer] and [StateSynchronizer] supports visibility
filtering. They expose a `visibility_filter` property that can be used to
configure filtering.

!!!warning
    When using visibility filtering with [RollbackSynchronizer] nodes, make
    sure to disable input broadcast. Otherwise, peers might receive input data
    from the player, but no state data from the server, leading to nodes being
    simulated without up-to-date state data.

## Default visibility

If there's no settings configured, the visibility filter falls back to the
`default_visibility`. By default it is `true`, meaning it will broadcast data
to all peers.

## Per-peer override

Visibility can also be set individually for each peer. This overrides the
default visibility for the given peer.

An override may be `true`, `false`, or not set. An override to `true` means
that the peer will be visible regardless of the default visibility. An override
to `false` means that the peer will not be visible regardless of the default
visibility. An unset override means it will fall back to the
`default_visibility`.

## Filter callbacks

Callbacks can also be registered, to filter peers dynamically. These filters
run before the per-peer overrides. If any of the filters reject the peer, it
will not receive data.

These callbacks receive the peer ID, and return a boolean:

```gd
filter.add_visibility_filter(func(peer: int):
  # Forbidden trick to halve your bandwidth :P
  return (peer % 2) == 0
)
```

## Update modes

Visibility filters keep an internal list of visible peers. To save on compute,
this list is only updated on certain configurable events. This is exposed as
its `update_mode` property, which can take on the following values:

Never
: Only update visibility when manually triggered using `update_visibility()`

On peer
: Only update when a peer joins or leaves

Per tick loop
: Update visibility before each tick loop

Per tick
: Update visibility before each network tick

Per rollback tick
: Update visibility *after* each rollback tick


[RollbackSynchronizer]: ../nodes/rollback-synchronizer.md
[StateSynchronizer]: ../nodes/state-synchronizer.md
