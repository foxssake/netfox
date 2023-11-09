# Ticking in Sync

## tl;dr

* Call `NetworkTime.start()` when gameplay starts and `NetworkTime.stop()` when
  it ends
* Subscribe to `NetworkTime.on_tick` signal for your game logic, instead of
  `_process` or `_physics_process`
* Use `NetworkTime.time` or `NetworkTime.tick` for current game time in seconds
  or ticks respectively

## The challenge

### Ticks

Multiplayer games, similarly to "regular" single-player games, are interactive
simulations. These consist of a game state ( e.g. the map, the players, the
enemies, etc. ), which are affected by the player via input ( e.g. keyboard and
mouse ).

Based on this input, the game state is updated regularly, many times a second,
giving the illusion that things happen continuously, in a fluid manner. We will
refer to these updates as *ticks*. The amount of ticks in a second is called
the *tickrate*.

It would sound logical to run games at as high as a tickrate as the PC can
handle to make everything smoother, but that can be actually counter-intuitive.
Some kinds of simulations can be sensitive to varying tickrates, and often the
actual tickrate doesn't even need to be that high. For slower games, you may be
able to get away with 30 ticks per second, instead of trying to push through
1200 updates per second over the Atlantic.

Note that this tickrate can differ from the game's render rate or *frames per
second* you see on the screen. For rendering, games generally either try to
match the display's refresh rate, or just output as many frames as they can.

Adding multiplayer to the mix complicates things a lot further, almost
irrespective of the architecture used, as handling player data and/or input
that can arrive at any moment can be difficult.

To simplify things and avoid a lot of edge cases, we can make sure that all
players' simulation runs at the same tickrate, so that for example one player
won't send twice as many updates as another in the same interval.

Having a fixed tickrate also makes it easier to think of each tick as a list of
steps we can do to make sure the simulation is consistent across all players,
for example:

1. Gather inputs from all players
1. Update player state
1. Broadcast changes

Imagine trying to do the same, but trying to account for the fact that one
player is running at 60 ticks per second and needs very frequent updates, the
other player is doing 30 ticks per second, and we may or may not receive any
input at all, or we may receive multiple inputs for the same tick.

### Times

Other times, we need to synchronize data or events that are tied to times. For
example, a player picked up a powerup and it will expire at the 27th second of
the game. Or player B will respawn at the 38th second.

For these cases, it's important to have all clients share a common notion of
time - what's the current time? While this does not need to be exact ( and
doesn't even need to be ), it is important that this shared notion to be
reasonably accurate, and for time to advance at the same rate at every player.

## NetworkTime

`NetworkTime` is netfox's solution to synchronizing time and tickrate for all
participants.

It drives the network tick loop, by emitting signals. Subscribing to these
guarantees that ticks are done at the same rate for all the participants.

While ticks happen at the same time, you may need different notions of time for
different use cases.

To use NetworkTime, call `NetworkTime.start()` when your game starts ( either
by hosting it or connecting to a server ), and call `NetworkTime.stop()` once
the game is over.

## Different times

### Local time

This is the simplest one of them all. It is basically the time that has elapsed
since NetworkTime is running - it starts at 0 and ticks upwards infinitely. Can
be used for things that are updated during network ticks, but don't need to be
synchronized across multiple devices, for example visuals.

* `NetworkTime.local_time` - The number of seconds elapsed in local time
* `NetworkTime.local_ticks` - The number of ticks elapsed in local time

### Remote time

To think in terms of shared time, the time on the host must be known. Due to
the laws of physics, we can't know *exactly* what's the time on the host. We
may ask, but it also takes time to send the question and receive the answer, so
the received info will be off. In addition, we can't know if the information
travels the same speed towards the host as it travels back to us. This latter
part is actually impossible to ever know - from our single point of view, it
might have taken 0% of the time to send the question, and 100% of the time to
receive the answer, and we wouldn't notice anything from it!

However, it is possible to *estimate* the time this roundtrip takes, and then
*assume* that information travels the same speed both ways - thus deduce that
latency is half of our estimated roundtrip.

And with that, we have an estimate of what's the time on the host.

Note that network conditions may change, thus the remote time is regularly
updated by the newest estimate. This also means that the remote time may jump
forwards or even backwards, as it's updated.

Can be used as a base for comparisons ( e.g. latency ), but *not recommended*
for tying game logic to it.

* `NetworkTime.remote_ticks` - Estimated time on the host, in ticks
* `NetwokrTime.remote_time` - Estimated time on the host, in seconds
* `NetworkTime.remote_rtt` - Estimated roundtrip time to host, in seconds

### Time

"Regular" time combines the best of both worlds - it is based on an estimate of
the host's time, but doesn't jump around. It is synced to the host once, and
then only ever updated in case the clocks go extremely out of sync for whatever
reason.

Use this as your go-to solution, and specifically when you need to share
timestamps between clients - for example sending a message saying Player C
fired their gun at tick #357.

* `NetworkTime.time` - Network time, in seconds
* `NetworkTime.ticks` - Network time, in ticks

## Utilities

NetworkTime also provides various methods and properties regarding time:

* `NetworkTime.tickrate`
* `NetworkTime.ticktime`
* `NetworkTime.tick_factor`

* `NetworkTime.ticks_to_seconds(ticks)`
* `NetworkTime.seconds_to_ticks(seconds)`
* `NetworkTime.ticks_between(from_seconds, to_seconds)`
* `NetworkTime.seconds_between(from_tick, to_tick)`

*TODO*: Reference docs

## Project Settings

Actual tickrate is controlled by project settings, and cannot be changed at
runtime. The settings themselves are under *Netfox/Time*.
