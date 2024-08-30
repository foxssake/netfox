extends Node
class_name ValueToBytes ##Mayhaps needs to become Autoload so as to use the logger.

#var_to_bytes is inefficient, see https://docs.godotengine.org/en/stable/tutorials/io/binary_serialization_api.html
#Contains 4 bytes in the header just for what type it is, should be 1 byte (flag can be last bit of 1st byte)
#With this class, the header is 0 bytes since we know the type beforehand ;)

static func get_byte_size(type: Variant.Type) -> int:
	match(type):
		TYPE_BOOL:
			return 1
		TYPE_INT, TYPE_FLOAT:
			return 4
		TYPE_STRING, TYPE_STRING_NAME: #Dynamic...
			return -1
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return 8
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return 12
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION, TYPE_RECT2, TYPE_RECT2I:
			return 16
		TYPE_AABB, TYPE_TRANSFORM2D:
			return 24
		TYPE_BASIS:
			return 36
		TYPE_TRANSFORM3D:
			return 48
		TYPE_NIL:
			push_error("Null inside get_byte_size!")
		_:
			push_error("Unknown type size")
	
	return -1

static func deserialize(serialized_value: PackedByteArray, type: Variant.Type) -> Variant:
	match(type):
		TYPE_BOOL:
			return serialized_value.decode_u8(0)
		TYPE_INT:
			return serialized_value.decode_s32(0)
		TYPE_FLOAT:
			return serialized_value.decode_float(0)
		TYPE_STRING:
			serialized_value.get_string_from_ascii()
		TYPE_STRING_NAME:
			serialized_value.get_string_from_ascii() as StringName
		TYPE_VECTOR2:
			return Vector2(serialized_value.decode_float(0), serialized_value.decode_float(4))
		TYPE_VECTOR2I:
			return Vector2i(serialized_value.decode_s32(0), serialized_value.decode_s32(4))
		TYPE_VECTOR3:
			return Vector3(serialized_value.decode_float(0), serialized_value.decode_float(4), serialized_value.decode_float(8))
		TYPE_VECTOR3I:
			return Vector3i(serialized_value.decode_s32(0), serialized_value.decode_s32(4), serialized_value.decode_s32(8))
		TYPE_QUATERNION:
			return Quaternion(serialized_value.decode_float(0), serialized_value.decode_float(4), serialized_value.decode_float(8), serialized_value.decode_float(12))
		TYPE_VECTOR4:
			return Vector4(serialized_value.decode_float(0), serialized_value.decode_float(4), serialized_value.decode_float(8), serialized_value.decode_float(12))
		TYPE_VECTOR4I:
			return Vector4i(serialized_value.decode_s32(0), serialized_value.decode_s32(4), serialized_value.decode_s32(8), serialized_value.decode_s32(12))
		TYPE_RECT2:
			return Rect2(Vector2(serialized_value.decode_float(0), serialized_value.decode_float(4)), Vector2(serialized_value.decode_float(8), serialized_value.decode_float(12)))
		TYPE_RECT2I:
			return Rect2i(Vector2i(serialized_value.decode_s32(0), serialized_value.decode_s32(4)), Vector2i(serialized_value.decode_s32(8), serialized_value.decode_s32(12)))
		TYPE_AABB:
			return AABB(Vector3(serialized_value.decode_float(0), serialized_value.decode_float(4), serialized_value.decode_float(8)), Vector3(serialized_value.decode_float(12), serialized_value.decode_float(16), serialized_value.decode_float(20)))
		TYPE_TRANSFORM2D:
			return Transform2D(Vector2(serialized_value.decode_float(0), serialized_value.decode_float(4)), Vector2(serialized_value.decode_float(8), serialized_value.decode_float(12)), Vector2(serialized_value.decode_float(16), serialized_value.decode_float(20)))
		TYPE_BASIS:
			return Basis(Vector3(serialized_value.decode_float(0), serialized_value.decode_float(4), serialized_value.decode_float(8)), Vector3(serialized_value.decode_float(12), serialized_value.decode_float(16), serialized_value.decode_float(20)), Vector3(serialized_value.decode_float(24), serialized_value.decode_float(28), serialized_value.decode_float(32)))
		TYPE_TRANSFORM3D:
			return Transform3D(Basis(Vector3(serialized_value.decode_float(0), serialized_value.decode_float(4), serialized_value.decode_float(8)), Vector3(serialized_value.decode_float(12), serialized_value.decode_float(16), serialized_value.decode_float(20)), Vector3(serialized_value.decode_float(24), serialized_value.decode_float(28), serialized_value.decode_float(32))), Vector3(serialized_value.decode_float(36), serialized_value.decode_float(40), serialized_value.decode_float(44)))
		TYPE_NIL:
			push_error("Failed to deserialize, null type!")
		_:
			push_error("Unknown type to deserialize!")
			
	return null

static var cache_transform3d: PackedByteArray #So a PackedByteArray of 48 bytes isn't made per frame!

#This should be a godot native function imo
static func serialize(value: Variant) -> PackedByteArray:
	return serialize_type(value, typeof(value))
	
static func serialize_type(value: Variant, type: Variant.Type) -> PackedByteArray:
	var serialized_value: PackedByteArray
	
	match(type):
		TYPE_BOOL:
			serialized_value.resize(1)
			serialized_value.encode_u8(0, value) #In the future to expand as bitfield
		TYPE_INT:
			serialized_value.resize(4)
			serialized_value.encode_s32(0, value)
		TYPE_FLOAT:
			serialized_value.resize(4)
			serialized_value.encode_float(0, value)
		TYPE_STRING:
			return (value as String).to_ascii_buffer() #Note that this is exclusively ASCII. If UTF-8+ (e.g. emojis or non-english, it should give error)			
		TYPE_STRING_NAME:
			return (value as StringName).to_ascii_buffer() #Note that this is exclusively ASCII. If UTF-8+ (e.g. emojis or non-english, it should give error)			
		TYPE_VECTOR2:
			serialized_value.resize(8)
			serialized_value.encode_float(0, (value as Vector2).x)
			serialized_value.encode_float(4, (value as Vector2).y)
		TYPE_VECTOR2I:
			serialized_value.resize(8)
			serialized_value.encode_s32(0, (value as Vector2).x)
			serialized_value.encode_s32(4, (value as Vector2).y)
		TYPE_VECTOR3:
			serialized_value.resize(12)
			serialized_value.encode_float(0, (value as Vector3).x)
			serialized_value.encode_float(4, (value as Vector3).y)
			serialized_value.encode_float(8, (value as Vector3).z)
		TYPE_VECTOR3I:
			serialized_value.resize(12)
			serialized_value.encode_s32(0, (value as Vector3i).x)
			serialized_value.encode_s32(4, (value as Vector3i).y)
			serialized_value.encode_s32(8, (value as Vector3i).z)
		TYPE_QUATERNION:
			serialized_value.resize(16)
			serialized_value.encode_float(0, (value as Quaternion).x)
			serialized_value.encode_float(4, (value as Quaternion).y)
			serialized_value.encode_float(8, (value as Quaternion).z)
			serialized_value.encode_float(12, (value as Quaternion).w)
		TYPE_VECTOR4:
			serialized_value.resize(16)
			serialized_value.encode_float(0, (value as Vector4).x)
			serialized_value.encode_float(4, (value as Vector4).y)
			serialized_value.encode_float(8, (value as Vector4).z)
			serialized_value.encode_float(12, (value as Vector4).w)
		TYPE_VECTOR4I:
			serialized_value.resize(16)
			serialized_value.encode_s32(0, (value as Vector4i).x)
			serialized_value.encode_s32(4, (value as Vector4i).y)
			serialized_value.encode_s32(8, (value as Vector3i).z)
			serialized_value.encode_s32(12, (value as Vector4i).w)
		TYPE_RECT2:
			serialized_value.resize(16)
			serialized_value.encode_float(0, (value as Rect2).position.x)
			serialized_value.encode_float(4, (value as Rect2).position.y)
			serialized_value.encode_float(8, (value as Rect2).size.x)
			serialized_value.encode_float(12, (value as Rect2).size.y)
		TYPE_RECT2I:
			serialized_value.resize(16)
			serialized_value.encode_s32(0, (value as Rect2i).position.x)
			serialized_value.encode_s32(4, (value as Rect2i).position.y)
			serialized_value.encode_s32(8, (value as Rect2i).size.x)
			serialized_value.encode_s32(12, (value as Rect2i).size.y)
		TYPE_AABB:
			serialized_value.resize(24)
			serialized_value.encode_float(0, (value as AABB).position.x)
			serialized_value.encode_float(4, (value as AABB).position.y)
			serialized_value.encode_float(8, (value as AABB).position.z)
			serialized_value.encode_float(12, (value as AABB).size.x)
			serialized_value.encode_float(16, (value as AABB).size.y)
			serialized_value.encode_float(20, (value as AABB).size.z)
		TYPE_TRANSFORM2D:
			serialized_value.resize(24)
			serialized_value.encode_float(0, (value as Transform2D).x.x)
			serialized_value.encode_float(4, (value as Transform2D).x.y)
			serialized_value.encode_float(8, (value as Transform2D).y.x)
			serialized_value.encode_float(12, (value as Transform2D).y.y)
			serialized_value.encode_float(16, (value as Transform2D).origin.x)
			serialized_value.encode_float(20, (value as Transform2D).origin.y)
		TYPE_BASIS:
			serialized_value.resize(36)
			serialized_value.encode_float(0, (value as Basis).x.x)
			serialized_value.encode_float(4, (value as Basis).x.y)
			serialized_value.encode_float(8, (value as Basis).x.z)
			serialized_value.encode_float(12, (value as Basis).y.x)
			serialized_value.encode_float(16, (value as Basis).y.y)
			serialized_value.encode_float(20, (value as Basis).y.z)
			serialized_value.encode_float(24, (value as Basis).z.x)
			serialized_value.encode_float(28, (value as Basis).z.y)
			serialized_value.encode_float(32, (value as Basis).z.z)
		TYPE_TRANSFORM3D:
			if (cache_transform3d.is_empty()): #I doubt this is faster than a malloc(48), but probably it is...
				cache_transform3d.resize(48)
			serialized_value = cache_transform3d
			serialized_value.encode_float(0, (value as Transform3D).basis.x.x)
			serialized_value.encode_float(4, (value as Transform3D).basis.x.y)
			serialized_value.encode_float(8, (value as Transform3D).basis.x.z)
			serialized_value.encode_float(12, (value as Transform3D).basis.y.x)
			serialized_value.encode_float(16, (value as Transform3D).basis.y.y)
			serialized_value.encode_float(20, (value as Transform3D).basis.y.z)
			serialized_value.encode_float(24, (value as Transform3D).basis.z.x)
			serialized_value.encode_float(28, (value as Transform3D).basis.z.y)
			serialized_value.encode_float(32, (value as Transform3D).basis.z.z)
			serialized_value.encode_float(36, (value as Transform3D).origin.x)
			serialized_value.encode_float(40, (value as Transform3D).origin.y)
			serialized_value.encode_float(44, (value as Transform3D).origin.z)
		#TYPE_RID: # RID is not meant to be serialized, but including it just in case.
			#serialized_value.resize(4)
			#serialized_value.encode_u32(0, (value as RID).get_id())
		#TYPE_NODE_PATH: #I will open a godot engine issue for this. No straightforward way to convert to string and .to_ascii_buffer?!
			#var nodepath: NodePath
			#(value as String).to_ascii_buffer() #Note that this is exclusively ASCII. If UTF-8+ (e.g. emojis or non-english, it should give error)			
		#TYPE_COLOR: # @GDScript.Color8() -> could have RGBA in a single byte (4 bytes) since each value is 0-255
		TYPE_NIL:
			push_error("Failed to serialize, null value!")
		_:
			push_error("Unrecognized type serialized. Either an array/packedarray/dictionary or plane/projection/color")
		
	
	return serialized_value
	
