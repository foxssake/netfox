extends Object
class_name NetfoxSchemas

static func variant() -> NetfoxSerializer:
	return VariantSerializer.new()

static func bool() -> NetfoxSerializer:
	return BoolSerializer.new()

static func uint8() -> NetfoxSerializer:
	return Uint8Serializer.new()

static func uint16() -> NetfoxSerializer:
	return Uint16Serializer.new()

static func uint32() -> NetfoxSerializer:
	return Uint32Serializer.new()

static func int32() -> NetfoxSerializer:
	return Int32Serializer.new()

static func float32() -> NetfoxSerializer:
	return Float32Serializer.new()

static func float64() -> NetfoxSerializer:
	return Float64Serializer.new()

static func vec2() -> NetfoxSerializer:
	return Vec2Serializer.new()

static func vec3() -> NetfoxSerializer:
	return Vec3Serializer.new()

# --- Internal Serializer Classes ---

class VariantSerializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void:
		var data = var_to_bytes(v)
		b.put_u32(data.size()) 
		b.put_data(data)
	
	func decode(b: StreamPeerBuffer) -> Variant:
		if b.get_available_bytes() < 4:
			return null 
		
		var size = b.get_u32()
		if size < 4 or b.get_available_bytes() < size:
			return null
		
		var result = b.get_data(size)
		if result[0] != OK:
			return null
			
		return bytes_to_var(result[1])

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

class Int32Serializer extends NetfoxSerializer:
	func encode(v: Variant, b: StreamPeerBuffer) -> void: b.put_32(v)
	func decode(b: StreamPeerBuffer) -> Variant: return b.get_32()

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