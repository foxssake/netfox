extends Object
class_name NetworkSchemas

static func variant() -> NetworkSchemaSerializer:
	return VariantSerializer.new()

static func string() -> NetworkSchemaSerializer:
	return StringSerializer.new()

static func bool8() -> NetworkSchemaSerializer:
	return BoolSerializer.new()

static func uint8() -> NetworkSchemaSerializer:
	return Uint8Serializer.new()

static func uint16() -> NetworkSchemaSerializer:
	return Uint16Serializer.new()

static func uint32() -> NetworkSchemaSerializer:
	return Uint32Serializer.new()

static func uint64() -> NetworkSchemaSerializer:
	return Uint64Serializer.new()

static func int8() -> NetworkSchemaSerializer:
	return Int8Serializer.new()

static func int16() -> NetworkSchemaSerializer:
	return Int16Serializer.new()

static func int32() -> NetworkSchemaSerializer:
	return Int32Serializer.new()

static func int64() -> NetworkSchemaSerializer:
	return Int64Serializer.new()

# TODO(v2): float16()

static func float32() -> NetworkSchemaSerializer:
	return Float32Serializer.new()

static func float64() -> NetworkSchemaSerializer:
	return Float64Serializer.new()

# signed fraction, i.e. floats in [-1., +1.] range
static func sfrac8() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint8(), -1., 1., 0, 0xFF)
	
static func sfrac16() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint16(), -1., 1., 0, 0xFFFF)
	
static func sfrac32() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint32(), -1., 1., 0, 0xFFFFFFFF)

# unsigned fraction, i.e. floats in [0, +1.] range
static func ufrac8() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint8(), 0., 1., 0, 0xFF)
	
static func ufrac16() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint16(), 0., 1., 0, 0xFFFF)
	
static func ufrac32() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint32(), 0., 1., 0, 0xFFFFFFFF)

# vector types
static func vec2t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericVec2Serializer.new(component_serializer)

static func vec2f32() -> NetworkSchemaSerializer:
	return vec2t(float32())

static func vec2f64() -> NetworkSchemaSerializer:
	return vec2t(float64())

static func vec3t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericVec3Serializer.new(component_serializer)

static func vec3f32() -> NetworkSchemaSerializer:
	return vec3t(float32())

static func vec3f64() -> NetworkSchemaSerializer:
	return vec3t(float64())

static func vec4t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericVec4Serializer.new(component_serializer)

static func vec4f32() -> NetworkSchemaSerializer:
	return vec4t(float32())

static func vec4f64() -> NetworkSchemaSerializer:
	return vec4t(float64())

# Quaternion
static func quatt(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericQuaternionSerializer.new(component_serializer)

static func quat32f() -> NetworkSchemaSerializer:
	return quatt(float32())

static func quat64f() -> NetworkSchemaSerializer:
	return quatt(float64())

# Transforms
static func transform2t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericTransform2DSerializer.new(component_serializer)

static func transform2f32() -> NetworkSchemaSerializer:
	return transform2t(float32())

static func transform2f64() -> NetworkSchemaSerializer:
	return transform2t(float64())

static func transform3t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericTransform3DSerializer.new(component_serializer)

static func transform3f32() -> NetworkSchemaSerializer:
	return transform3t(float32())

static func transform3f64() -> NetworkSchemaSerializer:
	return transform3t(float64())

# Collections

static func array_of(item_serializer: NetworkSchemaSerializer = variant(), size_serializer: NetworkSchemaSerializer = uint16()) -> NetworkSchemaSerializer:
	return ArraySerializer.new(item_serializer, size_serializer)

static func dictionary(key_serializer: NetworkSchemaSerializer = variant(), value_serializer: NetworkSchemaSerializer = variant(), size_serializer: NetworkSchemaSerializer = uint16()) -> NetworkSchemaSerializer:
	return DictionarySerializer.new(key_serializer, value_serializer, size_serializer)

# Serializer classes

class VariantSerializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_var(v, false)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return b.get_var(false)

class StringSerializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_utf8_string(str(v))

	func decode(b: StreamPeerBuffer) -> Variant:
		return b.get_utf8_string()

class BoolSerializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		b.put_u8(1 if v else 0)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return b.get_u8() > 0

class Uint8Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u8(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u8()

class Uint16Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u16(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u16()

class Uint32Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u32(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u32()

class Uint64Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_u64(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_u64()

class Int8Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_8(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_8()

class Int16Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_16(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_16()

class Int32Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_32(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_32()

class Int64Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_64(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_64()

class Float32Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_float(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_float()

class Float64Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_double(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_double()

class GenericVec2Serializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode(v.x, b)
		component.encode(v.y, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector2(component.decode(b), component.decode(b))

class GenericVec3Serializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode(v.x, b)
		component.encode(v.y, b)
		component.encode(v.z, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector3(
			component.decode(b), component.decode(b), component.decode(b)
		)

class GenericVec4Serializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
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

class GenericQuaternionSerializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
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

class GenericTransform2DSerializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
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

class GenericTransform3DSerializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
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

class QuantizingSerializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	var from_min: Variant
	var from_max: Variant
	var to_min: Variant
	var to_max: Variant
	
	func _init(
		p_component: NetworkSchemaSerializer, p_from_min: Variant,
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

class ArraySerializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	var size: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer, p_size: NetworkSchemaSerializer):
		component = p_component
		size = p_size
	
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var array := v as Array

		size.encode(array.size(), b)
		for item in array:
			component.encode(item, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		var array := []
		
		var item_count = size.decode(b)
		array.resize(item_count)
		for i in item_count:
			array[i] = component.decode(b)
		
		return array

class DictionarySerializer extends NetworkSchemaSerializer:
	var key_serializer: NetworkSchemaSerializer
	var value_serializer: NetworkSchemaSerializer
	var size_serializer: NetworkSchemaSerializer
	
	func _init(p_key_serializer: NetworkSchemaSerializer, p_value_serializer: NetworkSchemaSerializer, p_size_serializer: NetworkSchemaSerializer):
		key_serializer = p_key_serializer
		value_serializer = p_value_serializer
		size_serializer = p_size_serializer
	
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var dictionary := v as Dictionary

		size_serializer.encode(dictionary.size(), b)
		for key in dictionary:
			var value = dictionary[key]
			key_serializer.encode(key, b)
			value_serializer.encode(value, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		var dictionary := {}
		
		var size = size_serializer.decode(b)
		for i in size:
			var key = key_serializer.decode(b)
			var value = value_serializer.decode(b)
			dictionary[key] = value
		
		return dictionary
