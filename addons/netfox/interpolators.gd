extends Object
class_name Interpolators

## Tracks interpolation functions for various data types
##
## The interpolation system can be used to interpolate arbitrary values,
## regardless of their types. This is done by keeping a list of interpolators,
## with each handling a specific data type. These can be registered using
## [method register].
## [br][br]
## Later on, these values can either be interpolated using [method interpolate],
## or getting the interpolation function using [method find_for] and calling it.
## [br][br]
## By default, this class supports most built-in data types, aside from objects,
## arrays, and dictionaries. Custom interpolators can be registered, and will
## take precedence over built-in ones.
##
## @tutorial(Interpolators): https://foxssake.github.io/netfox/latest/netfox/guides/interpolators/

class Interpolator:
	var is_applicable: Callable
	var apply: Callable

	static func make(is_applicable: Callable, apply: Callable) -> Interpolator:
		var result := Interpolator.new()
		result.is_applicable = is_applicable
		result.apply = apply
		return result

## Fallback interpolator.
## [br][br]
## Returns the starting value in the first half of the tick, and the target
## value in the other half.
static var DEFAULT_INTERPOLATOR := Interpolator.make(
	func (v): return true,
	default_apply
)

## List of known interpolators.
## [br][br]
## This list is used to look up interpolators in [method find_for] and [method
## find_interpolator_for]. The list is ordered - the earlier an interpolator
## is in the list, the higher its precedence.
## [br][br]
## Do not modify - use [method register] instead.
static var interpolators: Array[Interpolator]

## Default interpolation function
static var default_apply: Callable = func(a, b, f): a if f < 0.5 else b

## Register an interpolator.
## [br][br]
## New interpolators are pushed to the front of the list, making them have
## precedence over existing ones. This can be useful in case you want to override
## the built-in interpolators.
static func register(is_applicable: Callable, apply: Callable) -> void:
	interpolators.push_front(Interpolator.make(is_applicable, apply))

## Find the appropriate interpolator for the given value.
## [br][br]
## If none was found, returns the default interpolator.
static func find_for(value: Variant) -> Callable:
	return find_interpolator_for(value).apply

## Find the appropriate interpolator instance for the given value.
## [br][br]
## If none was found, returns the default interpolator.
static func find_interpolator_for(value: Variant) -> Interpolator:
	for interpolator in interpolators:
		if interpolator.is_applicable.call(value):
			return interpolator

	return DEFAULT_INTERPOLATOR

## Interpolate between two values.
## [br][br]
## Note that this method looks up the appropriate interpolator using [method
## find_for] on every call. It is faster to call [method find_for] once, and
## call the resulting [Callable] repeatedly.
static func interpolate(a, b, f: float):
	return find_for(a).call(a, b, f)

static func _static_init() -> void:
	# Register built-in interpolators
	# Float
	register(
		func(a): return a is float,
		func(a: float, b: float, f: float): return lerpf(a, b, f)
	)

	# Int
	register(
		func(a): return a is int,
		func(a: int, b: int, f: float): return int(lerpf(a, b, f))
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
	register(
		func(a): return a is Vector4,
		func(a: Vector4, b: Vector4, f: float): return a.lerp(b, f)
	)

	register(
		func(a): return a is Vector2i,
		func(a: Vector2i, b: Vector2i, f: float): return Vector2i(Vector2(a).lerp(b, f))
	)
	register(
		func(a): return a is Vector3i,
		func(a: Vector3i, b: Vector3i, f: float): return Vector3i(Vector3(a).lerp(b, f))
	)
	register(
		func(a): return a is Vector4i,
		func(a: Vector4i, b: Vector4i, f: float): return Vector4i(Vector4(a).lerp(b, f))
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

	# Quaternion
	register(
		func(a): return a is Quaternion,
		func(a: Quaternion, b: Quaternion, f: float): return a.slerp(b, f)
	)

	# Basis
	register(
		func(a): return a is Basis,
		func(a: Basis, b: Basis, f: float): return a.slerp(b, f)
	)

	# Color
	register(
		func(a): return a is Color,
		func(a: Color, b: Color, f: float): return a.lerp(b, f)
	)
