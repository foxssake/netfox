extends Object
class_name NetfoxSchemas

static func variant() -> NetfoxSerializer:
	return VariantSerializer.new()

static func bool8() -> NetfoxSerializer:
	return BoolSerializer.new()

static func uint8() -> NetfoxSerializer:
	return Uint8Serializer.new()

static func uint16() -> NetfoxSerializer:
	return Uint16Serializer.new()

static func uint32() -> NetfoxSerializer:
	return Uint32Serializer.new()

static func uint64() -> NetfoxSerializer:
	return Uint64Serializer.new()

static func int8() -> NetfoxSerializer:
	return Int8Serializer.new()

static func int16() -> NetfoxSerializer:
	return Int16Serializer.new()

static func int32() -> NetfoxSerializer:
	return Int32Serializer.new()

static func int64() -> NetfoxSerializer:
	return Int64Serializer.new()

# TODO(v2): float16()

static func float32() -> NetfoxSerializer:
	return Float32Serializer.new()

static func float64() -> NetfoxSerializer:
	return Float64Serializer.new()

static func vec2() -> NetfoxSerializer:
	return Vec2Serializer.new()

static func vec3() -> NetfoxSerializer:
	return Vec3Serializer.new()

# TODO: Generic vector types that use a supplied schema per component
# TODO: Generic quaternion type
# TODO: Generic transform2D and transform3D type
# TODO: transform2f32, transform3f32
# TODO: vec2f16, vec2f32, vec2f64, vec3f16, vec3f32, vec3f64, vec4f16, vec4f32, vec4f64
# TODO: vec4, quat, transform?

# Serializer classes

class VariantSerializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_var(v, false)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return b.get_var(false)

class BoolSerializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_u8(1 if v else 0)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return b.get_u8() > 0

class Uint8Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u8(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u8()

class Uint16Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u16(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u16()

class Uint32Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u32(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u32()

class Uint64Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u64(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u64()

class Int8Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_8(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_8()

class Int16Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_16(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_16()

class Int32Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_32(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_32()

class Int64Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_64(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_64()

class Float32Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_float(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_float()

class Float64Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_double(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_double()

class Vec2Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_float(v.x)
		b.put_float(v.y)
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector2(b.get_float(), b.get_float())

class Vec3Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_float(v.x)
		b.put_float(v.y)
		b.put_float(v.z)
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector3(b.get_float(), b.get_float(), b.get_float())
