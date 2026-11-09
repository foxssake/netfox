# Simulation

!!!warning
    Simulation is *experimental*, meaning the API may change in breaking ways,
    and may be less stable than other features.

    *Simulator* is also a work in progress name, we couldn't find a better one
    yet. Suggestions are welcome!

Simulation is an alternative to [rollback], in the style of Counter-Strike's
netcode. Inputs are sent to the host, the host simulates everyone and
broadcasts the ground truth, and each player predicts only their own
character.

Provided by the *SimulatorServer* and *InputSenderServer* autoloads. Most of the
time you do not need to use these - the [Simulator] and [InputSender] nodes
handle simulation for you.

## Simulation or rollback?

| | Rollback | Simulation |
|---|---|---|
| Host | Rewinds and re-simulates when inputs arrive late | Runs one tick per tick, never changes the past |
| Late inputs | Applied by re-simulating | Predicted, late ones are never applied |
| Clients | Predict and re-simulate every rollback-aware node | Predict only their own player, show the truth for everything else |
| Game state | Kept consistent across every node | Only the simulated node itself |

Simulation is easier to code than rollback, because the game state is never
rewound under your feet. In exchange, remote objects are not predicted, and
interactions between players are decided by the host alone.

## Time model

The host's tick is the truth. The host simulates everyone, its own player and
remote players, at its current tick. Clients stamp their inputs ahead of their
own tick, so the inputs arrive before the host needs them. Clients predict
their own player up to tick + input lead.

Simulating tick T applies the inputs of tick T, calls `_simulated_tick(delta,
T, is_fresh)`, and the resulting state is recorded as the state of tick T + 1.
Example for the host, at tick 100:

```
after_tick       | input of tick 100 is recorded
SimulatorServer  | inputs of 100 applied, _simulated_tick(delta, 100)
                 | state recorded and sent as tick 101
after_tick_loop  | state of tick 101 is shown
```

This also puts Simulators in the same tick numbers as [StateSynchronizer]s,
which record state after a tick as tick + 1 too.

An authoritative peer restores the latest truth, then re-simulates up to its
newest input. Example, with a lead of 5 at tick 100, and the latest truth for
tick 97: restore the state of 97, then simulate ticks 97 .. 105 with their
inputs. The result is the state of tick 106, which is shown.

## Input lead

How far ahead clients stamp their inputs is the *input lead*. Each client
computes it on its own, from the round trip time measured by
[time synchronization]:

```
lead = ceil((rtt / 2 + rtt_jitter + margin) / ticktime)
```

Clients with a good connection get a small lead, clients with a bad connection
a big one, each only pays for its own connection. The host's own inputs need no
lead, so it is always 0 on the host.

The lead never goes above `netfox/simulator/max_input_lead`. Clients with an
even worse connection still play, but their inputs may arrive late, and the
host predicts them. The host drops inputs stamped further ahead than the
maximum lead.

The lead moves by at most 1 tick every second. No input is lost or sent twice
when it changes:

* growing by 1 skips a stamp, which is filled with a predicted input
* shrinking by 1 would stamp two inputs with the same tick, so the second one
  is held for a tick and merged into the next one

See [predicting and merging inputs] to customize these.

## View delay

*View delay* is the number of ticks between the tick a client stamps its
inputs with (`tick + lead`) and the tick of the host's simulation that the
client is seeing. When a client fires an input stamped `t`, it was seeing the
host's simulation at tick `t - view_delay`. The host uses this to find the tick
to rewind to when [registering projectiles](#projectiles).

The host only knows the stamped tick of a fire input, so the lead is part of
the view delay. Example, with a lead of 5:

```
client tick when firing      | 100
newest state the client sees | 97
fire input stamped           | 100 + 5 = 105
view delay                   | 105 - 97 = 8  -> host rewinds to 97
```

Clients measure their view delay every time a simulator state arrives from the
host, and send samples to the host periodically, or immediately if it changed
enough. The view delay is reported by the client, so the host doesn't trust it
blindly: it can't rewind further than `netfox/simulator/max_view_delay_ticks`.

## Projectiles

The host records simulation aware collision shapes and areas for every tick.
This gives developers a common past world space, where collisions can be
checked against what the firing player was seeing, with
`force_raycast_update()` or `force_shapecast_update()`.

Projectiles fired by clients are caught up on the host in this past world.
Register them on the host with
`SimulatorServer.register_projectile(projectile, firing_peer_id, fired_tick)`.

`fired_tick` is the tick of the fire input, e.g. the tick passed to
`_simulated_tick` when the fire input is applied, or the tick given by
`input_applied`.

```gdscript
func _simulated_tick(delta: float, tick: int, is_fresh: bool) -> void:
  if input.fire and multiplayer.is_server():
    var bullet := bullet_scene.instantiate() as Bullet
    get_tree().root.add_child(bullet)
    bullet.global_transform = muzzle.global_transform
    SimulatorServer.register_projectile(bullet, input.get_multiplayer_authority(), tick)
```

Projectiles must implement `step` and `is_alive`. `step` is called once for
every simulated tick:

```gdscript
extends Node3D
class_name Bullet

@export var speed: float = 50.0

@onready var _ray_cast: RayCast3D = $RayCast3D

func step(delta: float, tick: int) -> void:
  # Check the distance travelled this tick
  _ray_cast.target_position = Vector3.FORWARD * speed * delta
  _ray_cast.force_raycast_update()
  if _ray_cast.is_colliding():
    queue_free()
    return

  global_position += -global_basis.z * speed * delta

func is_alive() -> bool:
  return not is_queued_for_deletion()
```

The projectile is caught up from the tick of the host's simulation that the
firing peer was seeing at `fired_tick`. Projectiles are stepped after
Simulators, so stepping a projectile for tick T checks it against the world
after this tick's movement, the state of T + 1. The same is true while catching
up.

### Immediate checks

A projectile doesn't have to fly. For immediate checks, e.g. a hitscan weapon,
do a single raycast in the first `step`, then free the node. It's not a true
projectile, but it's checked against the same past world:

```gdscript
func step(delta: float, tick: int) -> void:
  _ray_cast.force_raycast_update()
  if _ray_cast.is_colliding():
    _hit(_ray_cast.get_collider())
  queue_free()

func is_alive() -> bool:
  return not is_queued_for_deletion()
```

### Simulation aware collision

To catch up projectiles, the host records collision shapes and areas for every
tick, and restores them while catching up. Add `CollisionShape3D`,
`CollisionShape2D`, `Area3D` or `Area2D` nodes to the
`simulation_aware_collision` group to have them recorded. Nodes that were not
alive at a tick are disabled while catching up.

!!!note
    Nodes are picked up when they enter the tree. Add them to the group in the
    scene, or in `_enter_tree()`.

## History size

Inputs and predicted states are kept for ticks in the future too, so the
InputSender and Simulator history buffers hold `history_limit` ticks of the
past, plus room for the future. Example with the defaults, 64 ticks of past and
1 second of maximum lead at 30 ticks per second:

```
room for the future | 30 + 2 (tolerance) = 32 ticks
buffer size         | 64 + 32 = 96 ticks
```

## Settings

*netfox/input_sender/input_redundancy*: each input packet also carries this
many previous inputs, in case some packets are lost.

*netfox/input_sender/history_limit*: ticks of past inputs kept.

*netfox/input_sender/enable_input_broadcast*: send inputs to every peer, not
only the host.

*netfox/simulator/full_state_interval*: ticks between full states, diff states
are sent in between. If set to 0, full states are never sent. If set to 1, only
full states are sent.

*netfox/simulator/enable_diff_states*: send only what changed since the
previous tick between full states.

*netfox/simulator/history_limit*: ticks of past simulator state kept, also how
far back projectiles can be caught up.

*netfox/simulator/max_view_delay_ticks*: most ticks the host rewinds when
catching up a client's projectile.

*netfox/simulator/input_lead_margin*: clients stamp their inputs ahead by `rtt
/ 2 + jitter + margin`, in seconds.

*netfox/simulator/max_input_lead*: clients never stamp their inputs further
ahead than this, in seconds. The host drops inputs stamped further ahead.

*netfox/simulator/view_delay_send_interval*: seconds between periodic view
delay samples sent by clients.

*netfox/simulator/view_delay_change_threshold*: view delay changes of at least
this many seconds are sent immediately.

## Limitations

* Lead changes show as a one-tick skip or repeat of the local player.
* Prediction errors are not smoothed, the local player snaps to the truth.
* View delay can't tell a lag spike from "nothing changed".
* Diff states are not acknowledged. A lost diff is only fixed by the next full
  state.
* Derived physics state, e.g. `is_on_floor()`, is not restored with the truth
  when re-simulating. See [Rollback caveats].

## Examples

See `examples/simulated-player` for a [Simulator] driven character, and
`examples/server-side-vehicle` for a physics tank using `input_applied` and
[predicting and merging inputs].

[rollback]: ./network-rollback.md
[Simulator]: ../nodes/simulator.md
[InputSender]: ../nodes/input-sender.md
[StateSynchronizer]: ../nodes/state-synchronizer.md
[time synchronization]: ./network-time-synchronizer.md
[predicting and merging inputs]: ../nodes/input-sender.md#predicting-and-merging-inputs
[Rollback caveats]: ../tutorials/rollback-caveats.md
