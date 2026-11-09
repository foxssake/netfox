extends VestTest

func get_suite_name() -> String:
	return "Interpolators"

func suite() -> void:
	define("interpolate()", func():
		test("should fall back to start value in first half", func():
			expect_equal(Interpolators.interpolate("from", "to", 0.25), "from")
		)

		test("should fall back to target value in second half", func():
			expect_equal(Interpolators.interpolate("from", "to", 0.75), "to")
		)
	)
