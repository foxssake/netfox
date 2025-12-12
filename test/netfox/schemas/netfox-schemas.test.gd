extends VestTest

func get_suite_name() -> String:
	return "NetfoxSchemas"

func suite() -> void:
	var cases := [
		["bool8", NetfoxSchemas.bool8(), true, 1],
		
		["int8", NetfoxSchemas.int8(), 107, 1],
		["int16", NetfoxSchemas.int16(), 107, 2],
		["int32", NetfoxSchemas.int32(), 107, 4],
		["int64", NetfoxSchemas.int64(), 107, 8],
		
		["uint8", NetfoxSchemas.uint8(), 107, 1],
		["uint16", NetfoxSchemas.uint16(), 107, 2],
		["uint32", NetfoxSchemas.uint32(), 107, 4],
		["uint64", NetfoxSchemas.uint64(), 107, 8],
		
		["float32", NetfoxSchemas.float32(), 2.0, 4],
		["float64", NetfoxSchemas.float64(), 2.0, 8],
		
		["vec2f32", NetfoxSchemas.vec2f32(), Vector2(+1, -1), 8],
		["vec2f64", NetfoxSchemas.vec2f64(), Vector2(+1, -1), 16],
		["vec3f32", NetfoxSchemas.vec3f32(), Vector3(+1, -1, .5), 12],
		["vec3f64", NetfoxSchemas.vec3f64(), Vector3(+1, -1, .5), 24],
		["vec4f32", NetfoxSchemas.vec4f32(), Vector4(+1, -1, .5, -5), 16],
		["vec4f64", NetfoxSchemas.vec4f64(), Vector4(+1, -1, .5, -5), 32],
		
		["transform2f32", NetfoxSchemas.transform2f32(), Transform2D.IDENTITY.rotated(37.), 24],
		["transform2f64", NetfoxSchemas.transform2f64(), Transform2D.IDENTITY.rotated(37.), 48],
		["transform3f32", NetfoxSchemas.transform3f32(), Transform3D.IDENTITY.rotated(Vector3.ONE, 37.), 48],
		["transform3f64", NetfoxSchemas.transform3f64(), Transform3D.IDENTITY.rotated(Vector3.ONE, 37.), 96],
	]

	for case in cases:
		var name := case[0] as String
		var serializer := case[1] as NetfoxSerializer
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
