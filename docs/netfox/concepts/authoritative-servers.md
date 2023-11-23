# Authoritative servers

The idea behind multiplayer servers is replicating state. As long each player
sees approximately the same things happening on their screen, the illusion of a
shared world works.

## Naive replication

To implement state replication, we could say that each player is responsible
for their own state. Players see the effects of their input instantly, as they
own their state and thus their avatar.

The issue is that clients can't be trusted. Your game client is distributed to
players, who run it in various environments. These environments are out of the
developer's control, and provide an attack surface for cheats.

For example, a modified game client might always report full HP no matter how
many hits the player takes. If each player is responsible for their own state,
the cheating player's full-HP state will be replicated to everyone else.

## Server as the source of truth

What can be controlled is the server, with dedicated hosting. Thus, the server
can be the single source of truth - or in other words, authoritative. Clients
send their inputs to the server, and the server responds with the updated game
state.

This makes cheating difficult, as players have limited influence over the game
world.

Game code can also be simplified - everything that affects the gameplay is run
on the server, while other things such as visual effects are run on the
clients.

The tradeoff is that it takes time for the updated game state to arrive from
the server. This necessitates techniques that mask this delay, such as
[Client-side prediction and Server reconciliation].

## Other approaches

Server-authoritative gameplay with CSP is not a silver bullet unfortunately,
and different games may require different approaches to network state
replication.

One good example is RTS games. These games can have 50+ or even hundreds of
units navigating the map and interacting. Broadcasting all of their state to
all of the players from the server may not always be feasible.

Instead, players broadcast their actions ( inputs ) to each other and update
their game state in lockstep. While this approach can scale up to hundreds of
units, it has other drawbacks. One of these is developing the game in such a
way that the simulation is exactly the same across multiple CPU architectures
down to each bit.

For more on this approach, see: [1500 Archers on a 28.8: Network Programming in
Age of Empires and Beyond]

For more approaches, see: [Networking for Physics Programmers]

[1500 Archers on a 28.8: Network Programming in Age of Empires and Beyond]: https://www.gamedeveloper.com/programming/1500-archers-on-a-28-8-network-programming-in-age-of-empires-and-beyond

[Networking for Physics Programmers]: https://www.gdcvault.com/play/1022195/Physics-for-Game-Programmers-Networking

[Client-side prediction and Server reconciliation]: https://www.gabrielgambetta.com/client-side-prediction-server-reconciliation.html
