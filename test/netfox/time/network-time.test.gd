extends VestTest

func get_suite_name() -> String:
	return "NetworkTime"

func suite() -> void:
	var ticktime := 1. / 30.
	var stretch_max := 1.25
	var stretch_min := 1. / stretch_max

	var stretch := func(ticks: float) -> float:
		return _NetworkTime._calculate_stretch_factor(ticks * ticktime, ticktime, stretch_max)

	test("should be neutral with no clock difference", func():
		expect_equal(stretch.call(0.), 1., "Clock is stretched with no clock difference!")
	)

	test("should reach max when a full tick behind", func():
		expect_true(is_equal_approx(stretch.call(1.), stretch_max))
	)

	test("should reach min when a full tick ahead", func():
		expect_true(is_equal_approx(stretch.call(-1.), stretch_min))
	)

	test("should clamp past a full tick of difference", func():
		expect_true(is_equal_approx(stretch.call(8.), stretch_max))
		expect_true(is_equal_approx(stretch.call(-8.), stretch_min))
	)

	test("should speed up when behind, slow down when ahead", func():
		expect_true(stretch.call(0.5) > 1., "Not speeding up while behind!")
		expect_true(stretch.call(-0.5) < 1., "Not slowing down while ahead!")
	)

	test("should be symmetric around neutral", func():
		for ticks in [0.1, 0.25, 0.5, 0.75, 1., 4.]:
			expect_true(
				is_equal_approx(stretch.call(ticks) * stretch.call(-ticks), 1.),
				"Speeding up and slowing down by %.2f ticks don't cancel out!" % ticks
			)
	)

	test("should stay within bounds", func():
		for ticks in [-4., -1., -0.5, 0., 0.5, 1., 4.]:
			var factor: float = stretch.call(ticks)
			expect_true(
				factor >= stretch_min and factor <= stretch_max,
				"Stretch factor %.4f at %.2f ticks is out of bounds!" % [factor, ticks]
			)
	)
