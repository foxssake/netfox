# BaseNetInput

Base class for Input nodes used with rollback.

During rollback, multiple logical ticks are simulated in the span of a single
network tick. Since these are just logical ticks, no actual input arrives during
them from the input devices.

The solution is to gather input before the tick loop, and use that input for
any new ticks simulated during the rollback.

## Gathering input

This class provides a virtual `_gather` method that you can override. Set the
variables configured in [RollbackSynchronizer] in your own implementation:

```gdscript
extends BaseNetInput

var movement: Vector3 = Vector3.ZERO

func _gather():
  movement = Vector3(
    Input.get_axis("move_west", "move_east"),
    0,
    Input.get_axis("move_north", "move_south")
  )
```

[RollbackSynchronizer]: ../../netfox/nodes/rollback-synchronizer.md
