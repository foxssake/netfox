extends VestTest

func get_suite_name() -> String:
	return "IntervalScheduler"

func suite() -> void:
	test("should never schedule on zero interval", func():
		var interval := _IntervalScheduler.new(0)
		expect_false(interval.is_now())
		expect_false(interval.is_now())
		expect_false(interval.is_now())
	)

	test("should always schedule on one interval", func():
		var interval := _IntervalScheduler.new(1)
		expect_true(interval.is_now())
		expect_true(interval.is_now())
		expect_true(interval.is_now())
	)

	test("should schedule on interval", func(): 
		var interval := _IntervalScheduler.new(3)
		expect_false(interval.is_now())
		expect_false(interval.is_now())
		expect_true(interval.is_now())

		expect_false(interval.is_now())
		expect_false(interval.is_now())
		expect_true(interval.is_now())
	)
