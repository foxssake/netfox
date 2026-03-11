extends VestTest

func get_suite_name() -> String:
	return "Bitset"

func suite():
	test("should be empty on create", func():
		var bits := _Bitset.new(2)
		expect_false(bits.get_bit(0))
		expect_false(bits.get_bit(1))
	)

	test("get_set_indices()", func():
		var bits := _Bitset.of_bools([0, 1, 1, 0])
		expect_equal(bits.get_set_indices(), [1, 2])
	)

	test("set_bit()", func():
		var bits := _Bitset.new(4)
		var expected := _Bitset.of_bools([0, 1, 0, 1])
		bits.set_bit(1)
		bits.set_bit(3)
		expect_equal(bits, expected)
	)

	test("clear_bit()", func():
		var bits := _Bitset.of_bools([0, 1, 1, 0])
		var expected := _Bitset.of_bools([0, 0, 1, 0])
		bits.clear_bit(1)
		bits.clear_bit(3)
		expect_equal(bits, expected)
	)

	test("toggle_bit()", func():
		var bits := _Bitset.of_bools([0, 1, 1, 0])
		var expected := _Bitset.of_bools([1, 0, 1, 0])
		bits.toggle_bit(0)
		bits.toggle_bit(1)
		expect_equal(bits, expected)
	)
