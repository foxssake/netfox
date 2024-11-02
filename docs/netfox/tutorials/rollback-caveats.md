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

* Rollback and physics-based games ( RigidBodies ) don't work at the moment
* Collision detection can work, but with workarounds

If there's a way to force an update for your given node type, it should work,
i.e.

* ShapeCast (2D and 3D) - [force_shapecast_update()] 
* ChacacterBody (2D and 3D) - [move_and_collide()] ( which has a test only
  mode )

### State Machines

State machines don't usually expect to be updated multiple times in a single
frame or be snapped back to a previous point in time. Be cautious of:

- Safeguards that implement a cooldown to changes.
- States based on values not updated in `_rollback_tick`.
- Transitions that enforce a specific order to state changes.
- Transitions that trigger on any state change.

The key concept to keep in mind is that netfox stores the configured states for
each processed tick. When it rolls back everything is snapped back to that
point in time and then played forward to the present in a single frame.


[force_shapecast_update()]: https://docs.godotengine.org/en/stable/classes/class_shapecast3d.html#class-shapecast3d-method-force-shapecast-update
[move_and_collide()]: https://docs.godotengine.org/en/stable/classes/class_physicsbody3d.html#class-physicsbody3d-method-move-and-collide
