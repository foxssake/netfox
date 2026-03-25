# Spawning and despawning in rollback

Some nodes that participate in rollback need to be despawned eventually. This
is true for projectiles that appear mid-game and then vanish when they hit
something, items that are picked up, or even enemies that are slain during
gameplay.

Freeing these nodes with `free()`, `queue_free()` or even removing them from
the scene tree could cause issues.

It is possible that the game needs to roll back to a tick where the node has
still existed. If that node is already destroyed, it cannot be restored to
resimulate the tick, causing mispredictions and artifacts.

The opposite can also happen - the game rewinds to a tick where the node did
not exist yet, but since it now exists, it will affect the game. For example, a
projectile may hit something before it was even fired.

## Liveness tracking

To avoid the above situations, the game can track when each node was spawned
and despawned. If the game needs to restore a tick where the node was not yet
spawned, or was already despawned, the node can be deactivated. If the game now
moves to a tick where the node was already spawned, it can be activated.

This is liveness tracking, implemented in *netfox*.

## Reacting to (de)spawning

For a node to be liveness aware, it must implement at least one of these methods:

```gd
func _rollback_spawn() -> void:
  pass

func _rollback_despawn() -> void:
  pass
```

Whenever a node needs to be deactivated before simulating a tick,
`_rollback_despawn()` is called. Whenever it needs to be activated,
`_rollback_spawn()` is called. These are picked up by [RollbackSynchronizer] or
[PredictiveSynchronizer].

What happens when a node is despawned is up to the game. This can range from
disabling collisions and hiding the model to temporarily removing the node from
the scene tree. Less invasive solutions can result in less complexity.

Implement the functionality necessary to restore a node to its active state, as
it should be seen by the player, in `_rollback_spawn()`.

Optionally, implement the following method as well:

```gd
func _rollback_destroy() -> void:
  pass
```

The above is called when the node has been inactive so long that it can be
safely freed. If it is not implemented, `queue_free()` is used as fallback.

## Requesting a despawn

To despawn a node, find the [RollbackSynchronizer] or [PredictiveSynchronizer]
node that manages it, and call `despawn()`:

```gd
extends Node3D

# [...]

@onready var synchronizer := $PredictiveSynchronizer as PredictiveSynchronizer

# [...]

func _rollback_tick(dt: float, _t: int, _if: bool) -> void:
  # [...]
  if distance_left < 0:
    synchronizer.despawn()
    return
```

This makes sure that every node managed by the synchronizer will be despawned
and spawned in unison.

## Using servers

When using servers instead of nodes, use the following methods:

- `RollbackLivenessServer.register()` to register the node for liveness tracking
    - This is where you can specify spawn, despawn and destroy callbacks
- `RollbackLivenessServer.deregister()` before freeing the node
- `RollbackLivenessServer.despawn()` to despawn

## Limitations

Liveness has a start and an end. It is a contiguous interval. It is not
possible to have a node spawn on tick @10, despawn on tick @15, and then spawn
again on tick @18. Think of `despawn()` as a rollback equivalent to
`queue_free()`.

In some cases, a despawn might be mispredicted. In that case, see
`RollbackLiveness.clear_despawn()`.

[RollbackSynchronizer]: ../nodes/rollback-synchronizer.md
[PredictiveSynchronizer]: ../nodes/predictive-synchronizer.md
