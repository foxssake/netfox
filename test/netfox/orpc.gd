extends VestTest

func get_suite_name() -> String:
	return "ORPC"

func after_each():
	ORPC.clear()

func test_encode_should_work():
	# Given
	var call_id := 15795
	var call_args := [1, "foo", false]
	var expected := [call_id, call_args]

	# When
	var encoded := ORPC._encode_call(call_id, call_args)
	var decoded := ORPC._decode_call(encoded)

	# Then
	expect_equal(decoded, expected)

func test_should_ignore_invalid_prefix():
	var buffer := PackedByteArray([75, 75, 75, 75])

	expect_not(ORPC._is_orpc_packet(buffer))

func test_should_call_registered():
	# Given
	var call_args := []
	var sender := 1377644
	var callable := func(a, b):
		call_args.append_array([ORPC.get_remote_sender_id(), a, b])

	var id := ORPC.register(callable, "test")
	var call_packet := ORPC._encode_call(id, ["foo", 2])

	# When
	ORPC._handle_packet(sender, call_packet)

	# Then
	expect_equal(call_args, [sender, "foo", 2])

func test_ids_should_never_be_negative():
	# Validate assumption that negative IDs are never generated, meaning it
	# is safe to encode them as uint32's
	var negative_ids := []
	for i in range(16384):
		var id := ORPC._gen_id(str(i))
		if id < 0:
			negative_ids.append([i, id])

	expect_empty(negative_ids)
