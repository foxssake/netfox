extends VestTest

func get_suite_name() -> String:
	return "NetworkSchemas"

func suite() -> void:
	var short_string := "netfox"
	var medium_string := "netfox. netfox? netfox! netfox? netfox. netfox! netfox? netfox. "
	var long_string := medium_string.repeat(16)
	var test_time := 4.

	var string_serializer := NetworkSchemas.string()
	var cstring_serializer := NetworkSchemas.c_string()

	var cases := [
		[string_serializer, short_string],
		[string_serializer, medium_string],
		[string_serializer, long_string],

		[cstring_serializer, short_string],
		[cstring_serializer, medium_string],
		[cstring_serializer, long_string],
	]

	for case in cases:
			var serializer := case[0] as NetworkSchemaSerializer
			var data := case[1] as String

			var buffer := StreamPeerBuffer.new()
			serializer.encode(data, buffer)
			var encoded := buffer.data_array.duplicate()

			var serializer_name := "string()" if serializer == string_serializer else "c_string()"

			test("%s - %d characters" % [serializer_name, data.length()], func():
				benchmark("encode", func(__):
					buffer.seek(0)
					serializer.encode(data, buffer)
				).with_duration(test_time).with_batch_size(2048).run()

				buffer.data_array = encoded
				benchmark("decode", func(__):
					buffer.seek(0)
					var decoded = serializer.decode(buffer)
				).with_duration(test_time).with_batch_size(2048).run()
			)

