extends VestTest

func get_suite_name() -> String:
	return "Graph"

func suite():
	test("should add link", func():
		var graph := _Graph.new()
		graph.link("foo", "bar")

		expect_linked(graph, "foo", "bar")
		expect_equal(graph.get_linked_from("foo"), ["bar"])
		expect_equal(graph.get_linked_to("bar"), ["foo"])
	)

	test("should remove link", func():
		var graph := _Graph.new()
		graph.link("foo", "bar")
		graph.link("quix", "baz")

		graph.unlink("foo", "bar")

		expect_unlinked(graph, "foo", "bar")
		expect_linked(graph, "quix", "baz")
		expect_empty(graph.get_linked_from("foo"))
		expect_empty(graph.get_linked_to("bar"))
	)

	test("should erase", func():
		var graph := _Graph.new()
		graph.link("foo", "bar")
		graph.link("foo", "baz")
		graph.link("quix", "baz")
		graph.link("oof", "foo")
		
		graph.erase("foo")
		
		expect_unlinked(graph, "foo", "bar")
		expect_unlinked(graph, "foo", "baz")
		expect_unlinked(graph, "oof", "foo")
		expect_linked(graph, "quix", "baz")
	)

func expect_linked(graph: _Graph, from: Variant, to: Variant):
	expect(graph.has_link(from, to), "Link %s -> %s was not present!")

func expect_unlinked(graph: _Graph, from: Variant, to: Variant):
	expect_not(graph.has_link(from, to), "Link %s -> %s was present!" % [from, to])
