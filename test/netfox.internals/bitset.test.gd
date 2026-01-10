extends VestTest

func get_suite_name() -> String:
	return "Bitset"

func suite():
	test("should be empty on create", func():
		var bits := _Bitset.new(2)
		expect_false(bits.get_bit(0))
		expect_false(bits.get_bit(1))
	)

	define("get_set_indices()", func():
		test("should return expected", func():
			var bits := _Bitset.of_bools([0, 1, 1, 0])
			expect_equal(bits.get_set_indices(), [1, 2])
		)
	)
	
	define("set_bit()", func():
		test("should set bit", func():
			var bits := _Bitset.new(8)
			bits.set_bit(2)
			
			expect_true(bits.get_bit(2))
		)
	)
