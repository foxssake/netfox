extends VestTest

func get_suite_name() -> String:
	return "HistoryBuffer"

func suite() -> void:
	var empty_buffer := _HistoryBuffer.new()
	var filled_buffer := _HistoryBuffer.of(16, { 2: "foo", 4: "bar", 8: "baz" })

	define("get latest", func():
		test("should not have latest if empty", func():
			expect_not(empty_buffer.has_at(16))
			expect_not(empty_buffer.has_latest_at(16))
		)

		test("should not have latest out of bounds", func():
			expect_not(filled_buffer.has_latest_at(0))
		)

		test("should return self on known item", func():
			expect_equal(filled_buffer.get_latest_index_at(2), 2)
			expect_equal(filled_buffer.get_latest_index_at(4), 4)
			expect_equal(filled_buffer.get_latest_index_at(8), 8)
		)

		test("should return latest on unknown", func():
			expect_equal(filled_buffer.get_latest_index_at(3), 2)
			expect_equal(filled_buffer.get_latest_index_at(5), 4)
			expect_equal(filled_buffer.get_latest_index_at(9), 8)
		)
	)

	define("set_at()", func():
		test("should set behind tail", func():
			var buffer := filled_buffer.duplicate()
			buffer.set_at(1, 4)
			expect(buffer.has_at(1))
		)

		test("should not set behind limit", func():
			var buffer := filled_buffer.duplicate()
			buffer.set_at(-64, 4)
			expect_not(buffer.has_at(-64))
		)

		test("should update prev buffer if in bounds", func():
			var buffer := filled_buffer.duplicate()
			buffer.set_at(6, "quoo")
			expect_not(buffer.has_at(7))
			expect(buffer.has_latest_at(7))
			expect_equal(buffer.get_latest_at(7), "quoo")
		)

		test("should update prev buffer if after head", func():
			var buffer := filled_buffer.duplicate()
			buffer.set_at(14, "quoo")
			expect_not(buffer.has_at(11))
			expect(buffer.has_latest_at(11))
			expect_equal(buffer.get_latest_at(11), "baz")
		)

		test("should jump if way after head", func():
			var buffer := filled_buffer.duplicate()
			buffer.set_at(130, "quoo")
			expect_not(buffer.has_at(8))
			expect_not(buffer.has_latest_at(8))
			expect_equal(buffer.size(), 1)
		)
	)
