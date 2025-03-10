extends VestTest

func get_suite_name() -> String:
	return "BiMap"

func suite():
	test("should return by key", func():
		var bimap := _BiMap.new()
		bimap.put(1, "foo")
		bimap.put(2, "bar")

		expect_equal(bimap.get_value(1), "foo")
	)

	test("should return by value", func():
		var bimap := _BiMap.new()
		bimap.put(1, "foo")
		bimap.put(2, "bar")

		expect_equal(bimap.get_key("foo"), 1)
	)

	test("should return null on unknown key", func():
		var bimap := _BiMap.new()
		bimap.put(1, "foo")
		bimap.put(2, "bar")

		expect_equal(bimap.get_value(3), null)
	)

	test("should return null on unknown value", func():
		var bimap := _BiMap.new()
		bimap.put(1, "foo")
		bimap.put(2, "bar")

		expect_equal(bimap.get_key("quix"), null)
	)

	test("should rewrite on known key", func():
		var bimap := _BiMap.new()
		bimap.put(1, "foo")
		bimap.put(2, "bar")

		bimap.put(1, "quix")

		expect_equal(bimap.get_value(1), "quix")
		expect_equal(bimap.get_key("foo"), null)
	)

	test("should rewrite on known value", func():
		var bimap := _BiMap.new()
		bimap.put(1, "foo")
		bimap.put(2, "bar")

		bimap.put(1, "quix")

		expect_equal(bimap.get_key("quix"), 1)
		expect_equal(bimap.get_key("foo"), null)
	)
