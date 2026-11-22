# InputSender

!!!warning
    InputSender is *experimental*, meaning the API may change in breaking
    ways, and may be less stable than other features. Feedback is welcome!

Stores inputs and sends them to the host. The host either runs them through a
[Simulator], or emits `input_applied` to run your own host side logic with
them.

## Configuring input

To use *InputSender*, add it as a child to the target node, and configure it:

*Root* is the root node for resolving node paths in inputs. Defaults to the
parent node.

*Input properties* define the input for the game simulation. Input is recorded
after every network tick. Make sure that nodes containing input properties are
owned by their respective players.

!!!note
    *InputSender* has authority over its inputs if any of its input nodes has
    authority. It's your responsibility to give all input nodes the same
    owner.

See [Property paths] on how to specify properties.

## Gathering input

Inputs are gathered once per tick, the same way as for rollback: set the input
properties before the tick, e.g. on `NetworkTime.before_tick_loop`:

```gdscript
extends Node
class_name PlayerInput

var movement: Vector3 = Vector3.ZERO

func _ready() -> void:
  NetworkTime.before_tick_loop.connect(_gather)

func _gather() -> void:
  if not is_multiplayer_authority():
    return

  movement = Vector3(
    Input.get_axis("move_west", "move_east"),
    0.0,
    Input.get_axis("move_north", "move_south")
  )
```

Clients stamp their inputs ahead of their own tick, so they arrive at the host
before the host needs them. See [input lead].

## Host side logic

`input_applied(tick, is_predicted)` is emitted on the host, after every tick,
when the inputs of `tick` are applied to the input properties. Use it to run
host side logic with the inputs, e.g. for physics vehicles synchronized with a
[StateSynchronizer]. Whatever you change here is recorded as the state of
`tick + 1`, the same as with [Simulator] and rollback.

```gdscript
func _on_input_sender_input_applied(tick: int, is_predicted: bool) -> void:
  engine_force = input.movement.y * engine_power
  # Don't fire on a guessed input
  if input.fire and not is_predicted:
    fire(tick)
```

It's emitted for every player, including the host's own. If the inputs of the
tick didn't arrive in time, `is_predicted` is true. Inputs arriving after their
tick was applied are never applied, the host doesn't change the past.

The signal is not emitted on clients, and only emitted if something is
connected to it.

## Predicting and merging inputs

Sometimes netfox needs an input that was never gathered, or has to fit two
gathered inputs into one tick:

* **predict**: an input is needed for a tick, but there is none. This happens
  when a client's input lead grows and a stamp is skipped, and when the host
  simulates a player whose input didn't arrive in time.
* **merge**: two inputs get the same stamp. This happens when a client's input
  lead shrinks.

Both are rare. By default, predicting copies the last input, and merging keeps
the newer input. For example, inputs that are only true for a single tick, like
a jump press, are copied by default when predicting, and the press happens
twice. When merging, the default drops the older press.

If the defaults don't fit, implement these methods in the *root* node's script:

```gdscript
# Return the input for a tick that has none. last is the latest input
# before it. May be called for multiple ticks in a row with the same last.
func _predict_input(last: Dictionary) -> Dictionary:
  var predicted := last.duplicate()
  predicted["Input:jump"] = false
  return predicted

# Return a single input made from two inputs that got the same tick.
# older was gathered one tick before newer.
func _merge_input(older: Dictionary, newer: Dictionary) -> Dictionary:
  var merged := newer.duplicate()
  merged["Input:jump"] = older["Input:jump"] or newer["Input:jump"]
  return merged
```

Inputs are dictionaries, with the paths in *input properties* as keys, and the
input values as values. Properties missing from the returned dictionary keep
the value from `last` or `newer`.

## Schemas

Use `set_schema()` to pick serializers for input properties, and lower
bandwidth. The schema must be the same on every peer:

```gdscript
input_sender.set_schema({
  "Input:movement": NetworkSchemas.vec3f32(),
  "Input:aim": NetworkSchemas.vec3f32(),
  "Input:is_firing": NetworkSchemas.bool8()
})
```

See [Network schemas] for more.

## Changing configuration

Call `process_settings()` after any change to configuration, or use
`add_input()`, which updates settings automatically.

Whenever the authority of the input nodes changes, call `process_authority()`.
Make sure to do this at the same time on all peers. If a [Simulator] listens to
this *InputSender*, update it too, see [Simulator](./simulator.md#changing-ownership).

## Visibility

*InputSender* has a `visibility_filter` that decides which peers will receive
updates. See [Visibility management].

[Simulator]: ./simulator.md
[StateSynchronizer]: ./state-synchronizer.md
[input lead]: ../guides/simulation.md#input-lead
[Property paths]: ../guides/property-paths.md
[Network schemas]: ../guides/network-schemas.md
[Visibility management]: ../guides/visibility-management.md
