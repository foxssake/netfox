extends Object
class_name Interpolators

static func interpolate_generic(a, b, f: float, type: Variant.Type):
	match(type):
		TYPE_FLOAT:
			return interpolate_float(a as float, b as float, f)
		TYPE_VECTOR2:
			return interpolate_vector2(a as Vector2, b as Vector2, f)
		TYPE_VECTOR3:
			return interpolate_vector3(a as Vector3, b as Vector3, f)
		TYPE_TRANSFORM2D:
			return interpolate_transform2d(a as Transform2D, b as Transform2D, f)
		TYPE_TRANSFORM3D:
			return interpolate_transform3d(a as Transform3D, b as Transform3D, f)
		TYPE_NIL:
			push_error("interpolating null value! a,b are %s" % [a,b])
			return a
		_:
			return lerp(a, b, f)

static func interpolate_float(a: float, b: float, f: float) -> float:
	return lerpf(a, b, f)

static func interpolate_vector2(a: Vector2, b: Vector2, f: float) -> Vector2:
	return a.lerp(b,f)
	
static func interpolate_vector3(a: Vector3, b: Vector3, f: float) -> Vector3:
	return a.lerp(b, f)

static func interpolate_transform2d(a: Transform2D, b: Transform2D, f: float) -> Transform2D:
	return a.interpolate_with(b, f)

static func interpolate_transform3d(a: Transform3D, b: Transform3D, f: float) -> Transform3D:
	return a.interpolate_with(b, f)
