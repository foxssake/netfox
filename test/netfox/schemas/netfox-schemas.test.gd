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
