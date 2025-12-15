extends VestTest

func get_suite_name() -> String:
	return "NetworkSchemas"

func suite() -> void:
	var has_half := (Engine.get_version_info().hex >= 0x040400) as bool
	
	var cases := [
		["variant", NetworkSchemas.variant(), 32, 12],
		["string", NetworkSchemas.string(), "hi!!", 8],
		
		["bool8", NetworkSchemas.bool8(), true, 1],
		
		["int8", NetworkSchemas.int8(), 107, 1],
		["int16", NetworkSchemas.int16(), 107, 2],
		["int32", NetworkSchemas.int32(), 107, 4],
		["int64", NetworkSchemas.int64(), 107, 8],
		
		["uint8", NetworkSchemas.uint8(), 107, 1],
		["uint16", NetworkSchemas.uint16(), 107, 2],
		["uint32", NetworkSchemas.uint32(), 107, 4],
		["uint64", NetworkSchemas.uint64(), 107, 8],
		
		["sfrac8", NetworkSchemas.sfrac8(), -63. / 255., 1],
		["sfrac16", NetworkSchemas.sfrac16(), -63. / 255., 2],
		["sfrac32", NetworkSchemas.sfrac32(), -63. / 255., 4],
		
		["ufrac8", NetworkSchemas.ufrac8(), 63. / 255., 1],
		["ufrac16", NetworkSchemas.ufrac16(), 63. / 255., 2],
		["ufrac32", NetworkSchemas.ufrac32(), 63. / 255., 4],
		
		["float16", NetworkSchemas.float16(), 2.0, 2 if has_half else 4],
		["float32", NetworkSchemas.float32(), 2.0, 4],
		["float64", NetworkSchemas.float64(), 2.0, 8],
		
		["vec2f16", NetworkSchemas.vec2f32(), Vector2(+1, -1), 4 if has_half else 8],
		["vec2f32", NetworkSchemas.vec2f32(), Vector2(+1, -1), 8],
		["vec2f64", NetworkSchemas.vec2f64(), Vector2(+1, -1), 16],
		["vec3f32", NetworkSchemas.vec3f32(), Vector3(+1, -1, .5), 12],
		["vec3f64", NetworkSchemas.vec3f64(), Vector3(+1, -1, .5), 24],
		["vec4f32", NetworkSchemas.vec4f32(), Vector4(+1, -1, .5, -5), 16],
		["vec4f64", NetworkSchemas.vec4f64(), Vector4(+1, -1, .5, -5), 32],
		
		["normal2f16", NetworkSchemas.normal2f16(), Vector2.RIGHT.rotated(PI / 6.), 2 if has_half else 4],
		["normal2f32", NetworkSchemas.normal2f32(), Vector2.RIGHT.rotated(PI / 6.), 4],
		["normal2f64", NetworkSchemas.normal2f64(), Vector2.RIGHT.rotated(PI / 6.), 8],
		["normal3f16", NetworkSchemas.normal3f16(), Vector3.UP, 4 if has_half else 8],
		["normal3f32", NetworkSchemas.normal3f32(), Vector3.UP, 8],
		["normal3f64", NetworkSchemas.normal3f64(), Vector3.UP, 16],
		
		["quat16f", NetworkSchemas.quat32f(), Quaternion.from_euler(Vector3.ONE), 8 if has_half else 16],
		["quat32f", NetworkSchemas.quat32f(), Quaternion.from_euler(Vector3.ONE), 16],
		["quat64f", NetworkSchemas.quat64f(), Quaternion.from_euler(Vector3.ONE), 32],
		
		["transform2f16", NetworkSchemas.transform2f32(), Transform2D.IDENTITY.rotated(37.), 12 if has_half else 24],
		["transform2f32", NetworkSchemas.transform2f32(), Transform2D.IDENTITY.rotated(37.), 24],
		["transform2f64", NetworkSchemas.transform2f64(), Transform2D.IDENTITY.rotated(37.), 48],
		["transform3f32", NetworkSchemas.transform3f32(), Transform3D.IDENTITY.rotated(Vector3.ONE, 37.), 48],
		["transform3f64", NetworkSchemas.transform3f64(), Transform3D.IDENTITY.rotated(Vector3.ONE, 37.), 96],
		
		["array", NetworkSchemas.array_of(NetworkSchemas.uint16()), [1, 2, 3], 8],
		["dictionary", NetworkSchemas.dictionary(NetworkSchemas.uint16(), NetworkSchemas.uint16()), { 1: 32, 2: 48 }, 10]
	]

	for case in cases:
		var name := case[0] as String
		var serializer := case[1] as NetworkSchemaSerializer
		var value = case[2]
		var expected_size := case[3] as int

		test(name, func():
			var buffer := StreamPeerBuffer.new()
			serializer.encode(value, buffer)
			buffer.seek(0)
			var decoded = serializer.decode(buffer)

			expect_equal(decoded, value)
			expect_equal(buffer.data_array.size(), expected_size)
		)
