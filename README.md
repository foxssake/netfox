<p style="text-align: center">
  <img src="docs/assets/netfox.svg" />
</p>

# netfox

A set of addons for responsive online games with the [Godot engine].

## Features

* ⏲️  Consistent timing across multiple machines
* 🖥️ Works well with, but not limited to client-server architecture
* 💨 Lag compensation with Client-side Prediction and Server-side Reconciliation
* 🧈 Smooth motion with easy-to-use interpolation
* 🛜 Bullet-proof connectivity with [noray] integration

## Addons

### netfox

Building multiplayer games always have an inherent complexity to them. This is
where [netfox], the core addon comes in to simplify life, by providing both
architecture-specific and just generally useful features.

#### Shared time

The basis of most multiplayer games is making sure the game state is the same
across clients, and that it's updated at the same rate. By providing
synchronized time, [netfox] ensures that all clients tick at the same rate, and
have a shared notion of time that they can use to communicate.

#### Lag compensation

Synchronizing state is the other important aspect - usually, the illusion of a
shared world is desired. However, blindly sending inputs to the server and
waiting for its response can sometimes take too much time - e.g. for player
motion. On the other hand, simply accepting each client's word on their state
opens up the game to cheating.



### netfox.noray

When building online games, it is difficult to guarantee connectivity between
peers, unless a dedicated server is in place to host the game.

To simplify the process of building player-hosted games, [netfox.noray]
bullet-proofs connectivity by integrating with [noray].

Supports NAT punchthrough, but [noray] can also act as a UDP proxy when a
punchthrough is not possible, guaranteeing connectivity between players.

[Godot engine]: https://godotengine.org/
[noray]: https://github.com/foxssake/noray
