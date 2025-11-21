extends Object
class_name NetfoxSchemas

static func variant() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): 
			var data = var_to_bytes(v)
			b.put_u32(data.size()) 
			b.put_data(data),
		func(b: StreamPeerBuffer):
			# 1. Do we have 4 bytes to read the size integer?
			if b.get_available_bytes() < 4:
				return null 
			
			var size = b.get_u32()
			
			# 2. Check for valid size (must be >= 4 for var_to_bytes)
			if size < 4:
				return null
			
			# 3. Do we have enough bytes in the buffer?
			if b.get_available_bytes() < size:
				return null
			
			# FIX IS HERE: get_data returns [error_code, data]
			var result = b.get_data(size)
			if result[0] != OK:
				return null
				
			var data = result[1] # Extract the actual PackedByteArray
			return bytes_to_var(data)
	)


## INTEGERS


static func uint8() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): b.put_u8(v),
		func(b: StreamPeerBuffer): return b.get_u8()
	)


static func uint16() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): b.put_u16(v),
		func(b: StreamPeerBuffer): return b.get_u16()
	)


static func uint32() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): b.put_u32(v),
		func(b: StreamPeerBuffer): return b.get_u32()
	)


static func int32() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): b.put_32(v),
		func(b: StreamPeerBuffer): return b.get_32()
	)


## FLOATS


static func float32() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): b.put_float(v),
		func(b: StreamPeerBuffer): return b.get_float()
	)


static func float64() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): b.put_double(v),
		func(b: StreamPeerBuffer): return b.get_double()
	)


## VECTORS


static func vec2() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): 
			b.put_float(v.x)
			b.put_float(v.y),
		func(b: StreamPeerBuffer): 
			return Vector2(b.get_float(), b.get_float())
	)


static func vec3() -> NetfoxSerializer:
	return NetfoxSerializer.new(
		func(v, b: StreamPeerBuffer): 
			b.put_float(v.x)
			b.put_float(v.y)
			b.put_float(v.z),
		func(b: StreamPeerBuffer): 
			return Vector3(b.get_float(), b.get_float(), b.get_float())
	)
