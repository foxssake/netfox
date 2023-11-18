# Interpolators

Tracks interpolators for various data types. Provided as an autoload.

To smooth out motion between network ticks, [TickInterpolator] interpolates
nodes' state properties between the current and the previous tick. The type of
data to be interpolated is not known in advance, and can be any built-in or
even custom type configured by the developer.

*Interpolators* provides methods to register interpolators for any data type,
and even provides some for built-in data types.

## Interpolating values

*Interpolators* can be used to interpolate between any two values, as long as
they hold the same data type:

```gdscript
extends Node3D

@export var target_node
@export var approach_time = 0.5

func _process(delta):
  # Approach target node, if it exists
  if target_node:
    var from_xform = global_transform
    var to_xform = target_node.global_transform
    var factor = delta / approach_time

    global_transform = Interpolators.interpolate(from_xform, to_xform, factor)
```

Note that in this case, *Interpolators* will try to look up the appropriate
interpolator based on the provided values. If no interpolator is found, a
fallback is used, that simply returns the value closer to *factor* - i.e. the
starting value if *factor* is less than 0.5 and the target value otherwise.

## Caching interpolators

To avoid having to look up the right interpolator every frame, you can cache
it:

```gdscript
extends Node3D

@export target_node
@export approach_time = 0.5

var interpolator

func _ready():
  interpolator = Interpolators.find_for(global_transform)

func _process(delta):
  # Approach target node, if it exists
  if target_node:
    var from_xform = global_transform
    var to_xform = target_node.global_transform
    var factor = delta / approach_time

    global_transform = interpolator.call(from_xform, to_xform, factor)
```

## Custom interpolators

*Interpolators* supports interpolators for custom data types, and even
overriding built-in interpolators. Both can be done by registering an
interpolator:

```gdscript
Interpolators.register(
  func(a): return a is float,               # Condition
  func(a, b, f): return lerpf(a, b, f * f)  # Interpolation
)
```

The above registers a custom interpolator by specifying a condition function
and an interpolation function. Since it applies to an already supported type,
it overrides the built-in interpolator.

During lookup, *Interpolators* calls the *condition* function of each
interpolator and returns the one whose *condition* function returns true. If
multiple interpolators are applicable, *Interpolators* returns the last
registered one.

The *interpolation* function receives the starting value *a*, the target value
*b* and the interpolation factor *f*.

## Built-in interpolators

The following types are supported by default:

* float
* Vector2
* Vector3
* Transform2D
* Transform3D

[TickInterpolator]: ../nodes/tick-interpolator.md
