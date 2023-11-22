# Servers, clients, and ownership

Much of this documentation discusses things in context of servers and clients.
This page is intended to clear up how this translates to Godot's concept of
multiplayer ownership.

## Ownership in Godot

In Godot's multiplayer system, each node belongs to a multiplayer peer, i.e. a
player. This can be set from scripts, and is not replicated. This means that
the logic assigning ownership to nodes must produce the same result on every
machine for things to work consistently.

## Ownership in netfox

To mesh better with Godot's existing conventions, *netfox* doesn't work in
terms of server and client, but uses ownership instead.

Whenever *the server* is mentioned, it refers to a given node's owner.

In practice, this means that nodes representing game state are and should be
owned by the server.

## Limitations

At the time of writing, ownership is hard-coded in some cases. One such case is
*NetworkTime*, which is always owned by the host peer and always takes the host
peer's time as reference.

This means that peer-to-peer games are not officially supported by *netfox*,
but might be able to work with some workarounds. If feasible, you can build
self-hosted games by including *netfox.noray*.

In theory, multiple players can own different parts of the game state, but
*netfox* is not tested for such use cases.
