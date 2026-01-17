extends VestTest

func get_suite_name() -> String:
	return "Graph"

func suite():
	var cases := [
		["tiny", 16, 2, 2048],
		["medium", 128, 4, 2048],
		["large", 1024, 16, 2048]
	]

	for case in cases:
		var name := case[0] as String
		var items := case[1] as int
		var depth := case[2] as int
		var batch := case[3] as int

		test("queries - %s graph, %d / %d" % [name, items, depth], func():
			var graph := _Graph.new()
			for i in items:
				for j in depth:
					graph.link(i, i + j)
			
			benchmark("get_linked_from()", func(__):
				var nodes := graph.get_linked_from(randi() % items)
			).with_duration(1.).with_batch_size(batch).run()
			
			benchmark("get_linked_to()", func(__):
				var nodes := graph.get_linked_to(randi() % items)
			).with_duration(1.).with_batch_size(batch).run()
			
			benchmark("has_link()", func(__):
				var nodes := graph.has_link(randi() % items, randi() % items)
			).with_duration(1.).with_batch_size(batch).run()
		)
