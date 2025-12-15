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

# signed fraction, i.e. floats in [-1., +1.] range
static func sfrac8() -> NetfoxSerializer:
	return QuantizingSerializer.new(uint8(), -1., 1., 0, 0xFF)
	
static func sfrac16() -> NetfoxSerializer:
	return QuantizingSerializer.new(uint16(), -1., 1., 0, 0xFFFF)
	
static func sfrac32() -> NetfoxSerializer:
	return QuantizingSerializer.new(uint32(), -1., 1., 0, 0xFFFFFFFF)

# unsigned fraction, i.e. floats in [0, +1.] range
static func ufrac8() -> NetfoxSerializer:
	return QuantizingSerializer.new(uint8(), 0., 1., 0, 0xFF)
	
static func ufrac16() -> NetfoxSerializer:
	return QuantizingSerializer.new(uint16(), 0., 1., 0, 0xFFFF)
	
static func ufrac32() -> NetfoxSerializer:
	return QuantizingSerializer.new(uint32(), 0., 1., 0, 0xFFFFFFFF)

# vector types
static func vec2t(component_serializer: NetfoxSerializer) -> NetfoxSerializer:
	return GenericVec2Serializer.new(component_serializer)

static func vec2f32() -> NetfoxSerializer:
	return vec2t(float32())

static func vec2f64() -> NetfoxSerializer:
	return vec2t(float64())

static func vec3t(component_serializer: NetfoxSerializer) -> NetfoxSerializer:
	return GenericVec3Serializer.new(component_serializer)

static func vec3f32() -> NetfoxSerializer:
	return vec3t(float32())

static func vec3f64() -> NetfoxSerializer:
	return vec3t(float64())

static func vec4t(component_serializer: NetfoxSerializer) -> NetfoxSerializer:
	return GenericVec4Serializer.new(component_serializer)

static func vec4f32() -> NetfoxSerializer:
	return vec4t(float32())

static func vec4f64() -> NetfoxSerializer:
	return vec4t(float64())

# Transforms
static func transform2t(component_serializer: NetfoxSerializer) -> NetfoxSerializer:
	return GenericTransform2DSerializer.new(component_serializer)

static func transform2f32() -> NetfoxSerializer:
	return transform2t(float32())

static func transform2f64() -> NetfoxSerializer:
	return transform2t(float64())

static func transform3t(component_serializer: NetfoxSerializer) -> NetfoxSerializer:
	return GenericTransform3DSerializer.new(component_serializer)

static func transform3f32() -> NetfoxSerializer:
	return transform3t(float32())

static func transform3f64() -> NetfoxSerializer:
	return transform3t(float64())

# Quaternion
static func quatt(component_serializer: NetfoxSerializer) -> NetfoxSerializer:
	return GenericQuaternionSerializer.new(component_serializer)

static func quat32f() -> NetfoxSerializer:
	return quatt(float32())

static func quat64f() -> NetfoxSerializer:
	return quatt(float64())

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

class GenericVec2Serializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	
	func _init(p_component: NetfoxSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode(v.x, b)
		component.encode(v.y, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector2(component.decode(b), component.decode(b))

class GenericVec3Serializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	
	func _init(p_component: NetfoxSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode(v.x, b)
		component.encode(v.y, b)
		component.encode(v.z, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector3(
			component.decode(b), component.decode(b), component.decode(b)
		)

class GenericVec4Serializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	
	func _init(p_component: NetfoxSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode(v.x, b)
		component.encode(v.y, b)
		component.encode(v.z, b)
		component.encode(v.w, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector4(
			component.decode(b), component.decode(b), component.decode(b), component.decode(b)
		)

class GenericQuaternionSerializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	
	func _init(p_component: NetfoxSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode(v.x, b)
		component.encode(v.y, b)
		component.encode(v.z, b)
		component.encode(v.w, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Quaternion(
			component.decode(b), component.decode(b), component.decode(b), component.decode(b)
		)

class GenericTransform2DSerializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	
	func _init(p_component: NetfoxSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var t := v as Transform2D
		
		component.encode(t.x.x, b); component.encode(t.x.y, b)
		component.encode(t.y.x, b); component.encode(t.y.y, b)
		component.encode(t.origin.x, b); component.encode(t.origin.y, b)

	func decode(b: StreamPeerBuffer) -> Variant:
		return Transform2D(
			Vector2(component.decode(b), component.decode(b)),
			Vector2(component.decode(b), component.decode(b)),
			Vector2(component.decode(b), component.decode(b)),
		)

class GenericTransform3DSerializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	
	func _init(p_component: NetfoxSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var t := v as Transform3D

		component.encode(t.basis.x.x, b); component.encode(t.basis.x.y, b); component.encode(t.basis.x.z, b)
		component.encode(t.basis.y.x, b); component.encode(t.basis.y.y, b); component.encode(t.basis.y.z, b)
		component.encode(t.basis.z.x, b); component.encode(t.basis.z.y, b); component.encode(t.basis.z.z, b)
		component.encode(t.origin.x, b); component.encode(t.origin.y, b); component.encode(t.origin.z, b)

	func decode(b: StreamPeerBuffer) -> Variant:
		return Transform3D(
			Basis(
				Vector3(component.decode(b), component.decode(b), component.decode(b)),
				Vector3(component.decode(b), component.decode(b), component.decode(b)),
				Vector3(component.decode(b), component.decode(b), component.decode(b)),
			),
			Vector3(component.decode(b), component.decode(b), component.decode(b))
		)

class QuantizingSerializer extends NetfoxSerializer:
	var component: NetfoxSerializer
	var from_min: Variant
	var from_max: Variant
	var to_min: Variant
	var to_max: Variant
	
	func _init(
		p_component: NetfoxSerializer, p_from_min: Variant,
		p_from_max: Variant, p_to_min: Variant, p_to_max: Variant
	):
		component = p_component
		from_min = p_from_min
		from_max = p_from_max
		to_min = p_to_min
		to_max = p_to_max

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var f := inverse_lerp(from_min, from_max, v)
		var s := lerp(to_min, to_max, f)
		component.encode(s, b)

	func decode(b: StreamPeerBuffer) -> Variant:
		var s := component.decode(b)
		var f := inverse_lerp(to_min, to_max, s)
		return lerp(from_min, from_max, f)
