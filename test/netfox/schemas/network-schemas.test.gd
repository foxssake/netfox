extends VestTest

func get_suite_name() -> String:
	return "NetworkSchemas"

func suite() -> void:
	var cases := [
		["bool8", NetworkSchemas.bool8(), true, 1],
		
		["int8", NetworkSchemas.int8(), 107, 1],
		["int16", NetworkSchemas.int16(), 107, 2],
		["int32", NetworkSchemas.int32(), 107, 4],
		["int64", NetworkSchemas.int64(), 107, 8],
		
		["uint8", NetworkSchemas.uint8(), 107, 1],
		["uint16", NetworkSchemas.uint16(), 107, 2],
		["uint32", NetworkSchemas.uint32(), 107, 4],
		["uint64", NetworkSchemas.uint64(), 107, 8],
		
		["float32", NetworkSchemas.float32(), 2.0, 4],
		["float64", NetworkSchemas.float64(), 2.0, 8],
		
		["vec2f32", NetworkSchemas.vec2f32(), Vector2(+1, -1), 8],
		["vec2f64", NetworkSchemas.vec2f64(), Vector2(+1, -1), 16],
		["vec3f32", NetworkSchemas.vec3f32(), Vector3(+1, -1, .5), 12],
		["vec3f64", NetworkSchemas.vec3f64(), Vector3(+1, -1, .5), 24],
		["vec4f32", NetworkSchemas.vec4f32(), Vector4(+1, -1, .5, -5), 16],
		["vec4f64", NetworkSchemas.vec4f64(), Vector4(+1, -1, .5, -5), 32],
		
		["transform2f32", NetworkSchemas.transform2f32(), Transform2D.IDENTITY.rotated(37.), 24],
		["transform2f64", NetworkSchemas.transform2f64(), Transform2D.IDENTITY.rotated(37.), 48],
		["transform3f32", NetworkSchemas.transform3f32(), Transform3D.IDENTITY.rotated(Vector3.ONE, 37.), 48],
		["transform3f64", NetworkSchemas.transform3f64(), Transform3D.IDENTITY.rotated(Vector3.ONE, 37.), 96],
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
