# Rollback

You may have noted earlier that documentation talks about *rollback*, *lag
compensation* and even *CSP* ( client-side prediction and server reconciliation
) multiple times, almost interchangeably.

The docs refer to CSP as rollback. They are a way to do lag compensation.

## The Challenge

You don't want your players to cheat. Nobody does. However, you publish your
game and give it to the player. The player's environment is entirely out of the
developer's control, players do whatever they want with it, which gives lots of
room to cheat.

For example, there were some applications that scanned a game's entire memory
and watched it for changes. When the player lost some health, the memory
address of the change was detected, and always set to its original value. This
way, whenever the player received damage in the game, this external application
would reset the player's health.

Since this was something people did in the early '00s, one could imagine that
cheating is still something very doable. All of this is to show that as game
developer, you do not want to trust the clients.

So what can you control? The server. This is how server-authoritative games
were born.

The idea is to simulate the whole game on the server and make it the source of
truth. Clients submit their inputs ( i.e. "I'm running north" ) on each tick,
the server updates the game state, and broadcasts the changes. All is swell.

Unless you consider latency. Let's say the latency is 50ms. Which means that
when the player presses a key to provide input, it will take 50ms for that
input to travel to the server, then some time passes as the server processes
all the inputs, then another 50ms for the new state to arrive.

Basically, it took slightly more than a tenth of a second before anything
happened on the player's screen after pressing a key. Aside from niche cases,
this is not very enjoyable. Not even mentioning that 50ms is a pretty decent
latency - in worse cases, it can be even 100-200ms, it can vary, it can jitter,
packets can be lost, all depending on network conditions.

This is where Client-Side Prediction and Server Reconciliation come in to save
the day. Instead of waiting for the server to return to us with a new game
state, we simulate *some* of the updates locally as well - for example, player
movement. We move the player along according to the input, then take a note of
the result. Once the server returns with the updated game state, clients can
adjust their local simulations accordingly. 

Most of the time, the clients' simulation will match that of the server, so
nothing happens. In case the client simulated something differently ( or was
cheating ), reconciliation kicks in and the difference will be corrected.

And thus, we can have our cake and eat it too - we consider the server as the
single source of truth, but also get responsive controls.

## Setting up rollback

Similar to Godot's `MultiplayerSynchronizer`, netfox's node for rollback is
`RollbackSynchronizer`. And much in the same vein, you can configure it with
state and input properties:

![Rollback config](../assets/rollback-config.png)

To use it, simply add it to your scene. The best practice is to add it directly
under the object you want it to synchronize.

*Root* is the node you want to synchronize. Typically this is the
synchronizer's parent, as per best practice. Not setting this field will result
in error.

*State properties* describe the synchronized object's current state - whatever
properties are listed here will be synchronized over the network. The
screenshot provides a good example for movement - we want to synchronize the
player's transform and velocity, so we can replicate motion across
clients.

*Input properties* point to properties describing the player's inputs. Inputs
are also replicated across the network, but are used to update the simulation.
The server uses these inputs to update its local state and broadcast it, which
the clients will accept as truth.

## Gathering input

To gather the player's input, all you need to do is set the configured *input
properties* from your code - the rest will be handled by
`RollbackSynchronizer`.

The other important part is *when* to set these properties. On each frame,
netfox checks the time elapsed since the last network tick, and runs as many
ticks as necessary. So, it may happen that during a single `_process` run, no
network ticks are run, a single tick is run, or even multiple.

When running multiple ticks in a single `_process`, it makes no sense to poll
your input devices for each tick, as they most probably won't change. Instead,
you can set your properties at the start of the network tick loop:

```gdscript
var movement: Vector3 = Vector3.ZERO

func _ready():
  NetworkTime.before_tick_loop.connect(_gather)

func _gather():
  if not is_multiplayer_authority():
    return

  movement = Vector3(
    Input.get_axis("move_west", "move_east"),
    Input.get_action_strength("move_jump"),
    Input.get_axis("move_north", "move_south")
  )
```

Notice that we only set the movement variable if we have the authority over the
input node. This is important, otherwise everyone would be controlling
everyone's avatar.

While it is useful to know the details, *netfox.extras* provides a convenience
class called `BaseNetInput` that you can extend to do pretty much the same
thing, but slightly easier:

```gdscript
extends BaseNetInput

var movement: Vector3 = Vector3.ZERO

func _gather():
  movement = Vector3(
  	Input.get_axis("move_west", "move_east"),
  	Input.get_action_strength("move_jump"),
  	Input.get_axis("move_north", "move_south")
  )
```

The two snippets above accomplish the same behaviour.

## Writing rollback-aware simulation

TODO:

* Example sim
