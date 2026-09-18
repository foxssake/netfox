# Hosting

Building a fun, multiplayer game is one part of the equation that *netfox*
helps with. However, many multiplayer games run over the internet. This can
necessitate both *hosting* your game, and possibly other online services like
*lobby management* or *matchmaking*.

## Dedicated vs. player hosting

Dedicated hosting means running server machines on the public internet that run
your game and host game sessions. These are always up and available, with
stable performance, as their only job is hosting your game.

The downside of dedicated hosting is cost. It might not be an option for
smaller teams or games.

Player hosting means distributing a version of the game capable of running as a
server, and letting your playerbase run it. This is essentially free for the
developer, since hosting is done by the players.

The downside is a potentially confusing hosting experience for the players,
depending on their technical familiarity. Most home PCs are behind a router,
which by default does not allow direct connections, disallowing hosting. This
can be worked around by an orchestration service such as [noray].

## Services and providers

The following section contains some examples of services, both ones that you
can run yourself, and ones that manage everything for you for a subscription.

### Fox's Sake Studio

Aside from *netfox*, we've also built solutions that help with various aspects
of hosting online games.

We build open source, self-hosted solutions that you can run on your own
servers. We also provide free hosted instances that you can use to try these
services before hosting your own.

#### noray

[noray] helps your players with hosting games themselves. Instead of having to
change their router settings, [noray] orchestrates the connection between your
players using [NAT punchthrough] or relaying as a fallback. A dedicated Godot
addon also comes with *netfox* for ease of use.

[noray] needs to be hosted on a public server. Since it only does orchestration
and relaying, its resource costs are low, meaning it can run on cheap VPS
instances too.

[noray]: https://github.com/foxssake/noray
[NAT punchthrough]: https://en.wikipedia.org/wiki/Hole_punching_(networking)

#### nohub

[nohub] tracks and manages in-game lobbies. Players can create lobbies letting
other players join, assign custom data such as lobby name, player count, etc.
Lobbies can also be locked and unlocked, made private or public.

[nohub] is a self-hosted service with low resource usage, and a dedicated Godot
addon.

[nohub]: https://github.com/foxssake/nohub

### Edgegap

[Edgegap] solves many of the hosting challenges online games face using one of
the world's largest public edge computing infrastructure. With edge computing,
the actual game servers can be anywhere in the world, as close to your players
as possible.

They provide managed solutions with subscription models, freeing you from the
burden of maintaining infrastructure.

They've also partnered up with *netfox* to provide [dedicated guides] on how to
use their services both with Godot and *netfox*.

While this page highlights some of their services, it is worth checking out
their full suite of offerings.

[Edgegap]: https://edgegap.com/
[dedicated guides]: https://docs.edgegap.com/docs/sample-projects/godot/netfox-forest-brawl

#### Hosting

[Edgegap]'s [Game Server Orchestration] solution lets you deploy your game
server anywhere in the world. This can be great for hosting your games actually
close to your players' locations, reducing latency and packet loss chance.

[Game Server Orchestration]: https://edgegap.com/platform/orchestration-hosting

#### Matchmaking

[Edgegap]'s [Matchmaking service] connects your players, making sure your teams
are full in your game sessions. It is greatly customizable, letting players
join individually or as groups, supports strategies for reducing latency, can
do automatic backfills, and more.

[Matchmaking service]: https://edgegap.com/platform/matchmaker

#### Lobbies

[Edgegap]'s [Server Browser] service offers automated session management
without having to deploy your own infrastructure. Its solution is customizable,
offers a game-ready authentication system, capacity management, analytics
tools, and more.

[Server Browser]: https://edgegap.com/platform/session-manager-server-browser
