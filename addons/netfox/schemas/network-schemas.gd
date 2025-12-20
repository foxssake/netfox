extends Object
class_name NetworkSchemas

## Provides various schema serializers
##
## While some method names are abbreviated, they use a few naming schemes. For 
## example: [br][br]
## [method uint16] - unsigned integer, 16 bits[br]
## [method vec2t] - [Vector2], component of specified [i]type[/i][br]
## [method vec3f32] - [Vector3], each component as a [method float32][br]
## [br]
## To handle collections, see [method array_of] and [method dictionary].
# TODO: Link tutorial

## Serialize any data type supported by [method @GlobalScope.var_to_bytes].
## [br][br]
## Final size depends on the value.
static func variant() -> NetworkSchemaSerializer:
	return VariantSerializer.new()

## Serialize strings in UTF-8 encoding.
## [br][br]
## Final size depends on the string, the string itself is zero-terminated.
static func string() -> NetworkSchemaSerializer:
	return StringSerializer.new()

## Serialize booleans as 8 bits.
## [br][br]
## Final size is 1 byte.
static func bool8() -> NetworkSchemaSerializer:
	return BoolSerializer.new()

## Serialize unsigned integers as 8 bits.
## [br][br]
## Final size is 1 byte.
static func uint8() -> NetworkSchemaSerializer:
	return Uint8Serializer.new()

## Serialize unsigned integers as 16 bits.
## [br][br]
## Final size is 2 bytes.
static func uint16() -> NetworkSchemaSerializer:
	return Uint16Serializer.new()

## Serialize unsigned integers as 32 bits.
## [br][br]
## Final size is 4 bytes.
static func uint32() -> NetworkSchemaSerializer:
	return Uint32Serializer.new()

## Serialize unsigned integers as 64 bits.
## [br][br]
## Final size is 8 bytes.
static func uint64() -> NetworkSchemaSerializer:
	return Uint64Serializer.new()

## Serialize signed integers as 8 bits.
## [br][br]
## Final size is 1 byte.
static func int8() -> NetworkSchemaSerializer:
	return Int8Serializer.new()

## Serialize signed integers as 16 bits.
## [br][br]
## Final size is 2 bytes.
static func int16() -> NetworkSchemaSerializer:
	return Int16Serializer.new()

## Serialize signed integers as 32 bits.
## [br][br]
## Final size is 4 bytes.
static func int32() -> NetworkSchemaSerializer:
	return Int32Serializer.new()

## Serialize signed integers as 64 bits.
## [br][br]
## Final size is 8 bytes.
static func int64() -> NetworkSchemaSerializer:
	return Int64Serializer.new()

## Serialize floats in half-precision, as 16 bits.
## [br][br]
## This is only supported in Godot 4.4 and up, earlier versions fall back to
## [method float32].
## [br][br]
## Final size is 2 bytes, 4 if using fallback.
static func float16() -> NetworkSchemaSerializer:
	return Float16Serializer.new()

## Serialize floats in single-precision, as 32 bits.
## [br][br]
## Final size is 4 bytes.
static func float32() -> NetworkSchemaSerializer:
	return Float32Serializer.new()

## Serialize floats in double-precision, as 64 bits.
## [br][br]
## Final size is 8 bytes.
static func float64() -> NetworkSchemaSerializer:
	return Float64Serializer.new()

## Serialize signed fractions in the [code][-1.0, +1.0][/code] range as 8 bits.
## [br][br]
## Final size is 1 byte.
static func sfrac8() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint8(), -1., 1., 0, 0xFF)

## Serialize signed fractions in the [code][-1.0, +1.0][/code] range as 16 bits.
## [br][br]
## Final size is 2 bytes.
static func sfrac16() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint16(), -1., 1., 0, 0xFFFF)

## Serialize signed fractions in the [code][-1.0, +1.0][/code] range as 32 bits.
## [br][br]
## Final size is 4 bytes.
static func sfrac32() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint32(), -1., 1., 0, 0xFFFFFFFF)

## Serialize signed fractions in the [code][0.0, 1.0][/code] range as 8 bits.
## [br][br]
## Final size is 1 byte.
static func ufrac8() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint8(), 0., 1., 0, 0xFF)

## Serialize signed fractions in the [code][0.0, 1.0][/code] range as 16 bits.
## [br][br]
## Final size is 2 bytes.
static func ufrac16() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint16(), 0., 1., 0, 0xFFFF)

## Serialize signed fractions in the [code][0.0, 1.0][/code] range as 32 bits.
## [br][br]
## Final size is 4 bytes.
static func ufrac32() -> NetworkSchemaSerializer:
	return QuantizingSerializer.new(uint32(), 0., 1., 0, 0xFFFFFFFF)

## Serialize [Vector2] objects, using [param component_serializer] to
## serialize each component of the vector.
## [br][br]
## Serializes 2 components, size depends on the [param component_serializer].
static func vec2t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericVec2Serializer.new(component_serializer)

## Serialize [Vector2] objects, with each component being a half-precision
## float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method vec2f32].
## [br][br]
## Final size is 4 bytes, 8 if using fallback.
static func vec2f16() -> NetworkSchemaSerializer:
	return vec2t(float16())

## Serialize [Vector2] objects, with each component being a single-precision
## float.
## [br][br]
## Final size is 8 bytes.
static func vec2f32() -> NetworkSchemaSerializer:
	return vec2t(float32())

## Serialize [Vector2] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 16 bytes.
static func vec2f64() -> NetworkSchemaSerializer:
	return vec2t(float64())

## Serialize [Vector3] objects, using [param component_serializer] to
## serialize each component of the vector.
## [br][br]
## Serializes 3 components, size depends on the [param component_serializer].
static func vec3t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericVec3Serializer.new(component_serializer)
	
## Serialize [Vector3] objects, with each component being a half-precision
## float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method vec3f32].
## [br][br]
## Final size is 6 bytes, 12 if using fallback.
static func vec3f16() -> NetworkSchemaSerializer:
	return vec3t(float16())

## Serialize [Vector3] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 12 bytes.
static func vec3f32() -> NetworkSchemaSerializer:
	return vec3t(float32())

## Serialize [Vector3] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 24 bytes.
static func vec3f64() -> NetworkSchemaSerializer:
	return vec3t(float64())

## Serialize [Vector4] objects, using [param component_serializer] to
## serialize each component of the vector.
## [br][br]
## Serializes 4 components, size depends on the [param component_serializer].
static func vec4t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericVec4Serializer.new(component_serializer)

## Serialize [Vector4] objects, with each component being a half-precision
## float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method vec4f32].
## [br][br]
## Final size is 8 bytes, 16 if using fallback.
static func vec4f16() -> NetworkSchemaSerializer:
	return vec4t(float16())

## Serialize [Vector4] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 16 bytes.
static func vec4f32() -> NetworkSchemaSerializer:
	return vec4t(float32())

## Serialize [Vector4] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 32 bytes.
static func vec4f64() -> NetworkSchemaSerializer:
	return vec4t(float64())

# Normals
## Serialize normalized [Vector2] objects, using [param component_serializer] to
## serialize each component of the vector.
## [br][br]
## Serializes 1 component, size depends on the [param component_serializer].
static func normal2t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return Normal2Serializer.new(component_serializer)

## Serialize normalized [Vector2] objects, with each component being a
## half-precision float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method normal2f32].
## [br][br]
## Final size is 2 bytes, 4 if using fallback.
static func normal2f16() -> NetworkSchemaSerializer:
	return normal2t(float16())

## Serialize normalized [Vector2] objects, with each component being a
## single-precision float.
## [br][br]
## Final size is 4 bytes.
static func normal2f32() -> NetworkSchemaSerializer:
	return normal2t(float32())

## Serialize normalized [Vector2] objects, with each component being a
## double-precision float.
## [br][br]
## Final size is 8 bytes.
static func normal2f64() -> NetworkSchemaSerializer:
	return normal2t(float64())

## Serialize normalized [Vector3] objects, using [param component_serializer] to
## serialize each component of the vector.
## [br][br]
## Serializes 2 components, size depends on the [param component_serializer].
static func normal3t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return Normal3Serializer.new(component_serializer)

## Serialize normalized [Vector3] objects, with each component being a
## half-precision float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method normal3f32].
## [br][br]
## Final size is 4 bytes, 8 if using fallback.
static func normal3f16() -> NetworkSchemaSerializer:
	return normal3t(float16())

## Serialize normalized [Vector3] objects, with each component being a
## single-precision float.
## [br][br]
## Final size is 8 bytes.
static func normal3f32() -> NetworkSchemaSerializer:
	return normal3t(float32())

## Serialize normalized [Vector3] objects, with each component being a
## double-precision float.
## [br][br]
## Final size is 16 bytes.
static func normal3f64() -> NetworkSchemaSerializer:
	return normal3t(float64())

# Quaternion
## Serialize [Quaternion] objects, using [param component_serializer] to
## serialize each component of the quaternion.
## [br][br]
## Serializes 4 components, size depends on the [param component_serializer].
static func quatt(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericQuaternionSerializer.new(component_serializer)

## Serialize [Quaternion] objects, with each component being a half-precision
## float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method quat32f].
## [br][br]
## Final size is 8 bytes, 16 if using fallback.
static func quat16f() -> NetworkSchemaSerializer:
	return quatt(float16())

## Serialize [Quaternion] objects, with each component being a single-precision
## float.
## [br][br]
## Final size is 16 bytes.
static func quat32f() -> NetworkSchemaSerializer:
	return quatt(float32())

## Serialize [Quaternion] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 32 bytes.
static func quat64f() -> NetworkSchemaSerializer:
	return quatt(float64())

# Transforms
## Serialize [Transform2D] objects, using [param component_serializer] to
## serialize each component of the transform.
## [br][br]
## Serializes a 2x3 matrix in 6 components, final size depends on [param 
## component_serializer].
static func transform2t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericTransform2DSerializer.new(component_serializer)

## Serialize [Transform2D] objects, with each component being a half-precision
## float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method transform2f32].
## [br][br]
## Final size is 12 bytes, 24 if using fallback.
static func transform2f16() -> NetworkSchemaSerializer:
	return transform2t(float16())

## Serialize [Transform2D] objects, with each component being a single-precision
## float.
## [br][br]
## Final size is 24 bytes.
static func transform2f32() -> NetworkSchemaSerializer:
	return transform2t(float32())

## Serialize [Transform2D] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 48 bytes.
static func transform2f64() -> NetworkSchemaSerializer:
	return transform2t(float64())

## Serialize [Transform3D] objects, using [param component_serializer] to
## serialize each component of the transform.
## [br][br]
## Serializes a 3x4 matrix in 12 components, final size depends on [param 
## component_serializer].
static func transform3t(component_serializer: NetworkSchemaSerializer) -> NetworkSchemaSerializer:
	return GenericTransform3DSerializer.new(component_serializer)
	
## Serialize [Transform3D] objects, with each component being a half-precision
## float.
## [br][br]
## This is only supported in Godot 4.4 and up. Earlier versions fall back to
## [method transform3f32].
## [br][br]
## Final size is 24 bytes, 48 if using fallback.
static func transform3f16() -> NetworkSchemaSerializer:
	return transform3t(float16())

## Serialize [Transform3D] objects, with each component being a single-precision
## float.
## [br][br]
## Final size is 48 bytes.
static func transform3f32() -> NetworkSchemaSerializer:
	return transform3t(float32())

## Serialize [Transform2D] objects, with each component being a double-precision
## float.
## [br][br]
## Final size is 96 bytes.
static func transform3f64() -> NetworkSchemaSerializer:
	return transform3t(float64())

# Collections

## Serialize homogenoeous arrays, using [param item_serializer] to
## serialize each item, and [param size_serializer] to serialize the array's
## size.
## [br][br]
## To serialize heterogenoeous arrays, use [method variant] as the item
## serializer.
## [br][br]
## Final size is [code]sizeof(size_serializer) + array.size() * sizeof(item_serializer)[/code]
static func array_of(item_serializer: NetworkSchemaSerializer = variant(), size_serializer: NetworkSchemaSerializer = uint16()) -> NetworkSchemaSerializer:
	return ArraySerializer.new(item_serializer, size_serializer)

## Serialize homogenoeous dictionaries, using [param key_serialize] and
## [param value_serializer] to serialize key-value pairs, and
## [param size_serializer] to serialize the number of entries.
## [br][br]
## If either the keys or values are not homogenoeous, use [method variant].
## [br][br]
## Final size is [code]sizeof(size_serializer) + dictionary.size() * (sizeof(key_serializer) + sizeof(value_serializer))[/code]
static func dictionary(key_serializer: NetworkSchemaSerializer = variant(),
	value_serializer: NetworkSchemaSerializer = variant(),
	size_serializer: NetworkSchemaSerializer = uint16()) -> NetworkSchemaSerializer:
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

class Float16Serializer extends NetworkSchemaSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		if Engine.get_version_info().hex >= 0x040400:
			b.put_half(v)
		else:
			b.put_float(v)

	func decode(b: StreamPeerBuffer) -> Variant:
		if Engine.get_version_info().hex >= 0x040400:
			return b.get_half()
		else:
			return b.get_float()

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

class Normal2Serializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		component.encode((v as Vector2).angle(), b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector2.RIGHT.rotated(component.decode(b))

class Normal3Serializer extends NetworkSchemaSerializer:
	var component: NetworkSchemaSerializer
	
	func _init(p_component: NetworkSchemaSerializer):
		component = p_component

	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var uv := (v as Vector3).octahedron_encode()
		component.encode(uv.x, b)
		component.encode(uv.y, b)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		return Vector3.octahedron_decode(
			Vector2(component.decode(b), component.decode(b))
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
