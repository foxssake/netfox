extends VestTest

func get_suite_name() -> String:
	return "Graph"

func suite():
	test("should add link", func():
		var graph := _Graph.new()
		graph.link("foo", "bar")

		expect(graph.has_link("foo", "bar"))
		expect_equal(graph.get_linked_from("foo"), ["bar"])
		expect_equal(graph.get_linked_to("bar"), ["foo"])
	)

	test("should remove link", func():
		var graph := _Graph.new()
		graph.link("foo", "bar")
		graph.link("quix", "baz")

		graph.unlink("foo", "bar")

		expect_not(graph.has_link("foo", "bar"))
		expect(graph.has_link("quix", "baz"))
		expect_empty(graph.get_linked_from("foo"))
		expect_empty(graph.get_linked_to("bar"))
	)

	test("should erase", func():
		var graph := _Graph.new()
		graph.link("foo", "bar")
		graph.link("foo", "baz")
		graph.link("quix", "baz")
		
		graph.erase("foo")
		
		expect_not(graph.has_link("foo", "bar"), "Link was not erased!")
		expect_not(graph.has_link("foo", "baz"), "Link was not erased!")
		expect(graph.has_link("quix", "baz"), "Link was erased!")
	)
