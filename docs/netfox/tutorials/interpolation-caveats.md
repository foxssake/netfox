# Interpolation caveats

While netfox runs netcode at a fixed rate, the game may render frames at a
higher, varying framerate. Interpolation smooths out the difference between
tickrate and framerate, when using [TickInterpolator].

Below are some aspects that may catch users off guard.

### Interpolate only visuals

A node's state may consist of multiple properties, some of which affect its
appearance ( e.g. position, rotation, scale ), some are only relevant to the
simulation - e.g. most objects look the same regardless of their velocity, even
though it's important for simulating their behavior.

Since interpolation matters only for the game's visuals, it's enough to
interpolate only the properties that affect the game's visuals.

### Rotation vs. Quaternion vs. Transform

Interpolating `rotation` may lead to glitchy results when an object makes a
full turn. This stems from the way `rotation` works - it represents the amount
of rotation per axis, in Euler angles. Using Euler angles to interpolate
rotations doesn't work well, as they can end up interpolating from -180 degrees
to +180 numerically. The expected behavior would be to go from -180 to +180
instantly, since they represent the same rotation. The same thing happens in
animation software as well, when trying to interpolate with Euler angles.

What to do instead:

* Interpolate the whole `transform`
* Interpolate `quaternion` - represents rotation, but better suited to
  interpolation

For more, see Godot docs on [3D transforms]

[TickInterpolator]: ../nodes/tick-interpolator.md
[3D transforms]: https://docs.godotengine.org/en/stable/tutorials/3d/using_transforms.html

