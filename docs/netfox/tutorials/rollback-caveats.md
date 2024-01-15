# Rollback caveats

As with most things, rollback has some drawbacks along with its benefits.

### CharacterBody velocity

Godot's `move_and_slide()` uses the `velocity` property, which is set in
meters/second. The method assumes a delta time based on what kind of frame is
being run. However, it is not aware of *netfox*'s network ticks, which means
that movement speed will be off.

To counteract this, multiply velocity with `NetworkTime.physics_factor`, which
will adjust for the difference between Godot's *assumed* delta time and the
delta time *netfox* is using.

If you don't want to lose your original velocity ( e.g. because it accumulates
acceleration over time ), divide by the same property after using any built-in
method. For example:

```gdscript
# Apply movement
velocity *= NetworkTime.physics_factor
move_and_slide()
velocity /= NetworkTime.physics_factor
```

### CharacterBody on floor

CharacterBodies only update their `is_on_floor()` state only after a
`move_and_slide()` call.

This means that during rollback, the position is updated, but the
`is_on_floor()` state is not.

As a work-around, do a zero-velocity move before checking if the node is on the
floor:

```gdscript
extends CharacterBody3D

func _rollback_tick(delta, tick, is_fresh):
	# Add the gravity.
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta

  # ...

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity
```

### Physics updates

Godot's physics system is updated only during `_physics_process`, while
rollback updates the game state multiple times during a single frame.

Unfortunately, Godot does not support manually updating or stepping the physics
system, [at least at the time of writing](https://github.com/godotengine/godot/pull/76462).
This means that:

* Rollback and physics-based games don't work at the moment
* Collision detection can work, but with workarounds

If there's a way to force an update for your given node type, it should work.
