extends Object
class_name Interpolators

class Interpolator:
	var is_applicable: Callable
	var apply: Callable
	
	static func make(is_applicable: Callable, apply: Callable) -> Interpolator:
		var result = Interpolator.new()
		result.is_applicable = is_applicable
		result.apply = apply
		return result

static var DEFAULT_INTERPOLATOR = Interpolator.make(
	func (v): return true,
	func (a, b, f): return a if f < 0.5 else b
)

static var interpolators: Array[Interpolator]
static var default_apply: Callable = func(a, b, f): a if f < 0.5 else b

## Register an interpolator.
##
## New interpolators are pushed to the front of the list, making them have 
## precedence over existing ones. This can be useful in case you want to override
## the built-in interpolators.
static func register(is_applicable: Callable, apply: Callable):
	interpolators.push_front(Interpolator.make(is_applicable, apply))

## Find the appropriate interpolator for the given value.
##
## If none was found, the default interpolator is returned.
static func find_for(value) -> Callable:
	for interpolator in interpolators:
		if interpolator.is_applicable.call(value):
			return interpolator.apply
	
	return DEFAULT_INTERPOLATOR.apply

## Interpolate between two values.
##
## Note, that it is usually faster to just cache the Callable returned by find_for
## and call that, instead of calling interpolate repeatedly. The latter will have 
## to lookup the appropriate interpolator on every call.
static func interpolate(a, b, f: float):
	return find_for(a).call(a, b, f)

static func _static_init():
	# Register built-in interpolators
	# Float
	register(
		func(a): return a is float,
		func(a: float, b: float, f: float): return lerpf(a, b, f)
	)
	
	# Vector
	register(
		func(a): return a is Vector2,
		func(a: Vector2, b: Vector2, f: float): return a.lerp(b, f)
	)
	register(
		func(a): return a is Vector3,
		func(a: Vector3, b: Vector3, f: float): return a.lerp(b, f)
	)
	
	# Transform
	register(
		func(a): return a is Transform2D,
		func(a: Transform2D, b: Transform2D, f: float): return a.interpolate_with(b, f)
	)
	register(
		func(a): return a is Transform3D,
		func(a: Transform3D, b: Transform3D, f: float): return a.interpolate_with(b, f)
	)
