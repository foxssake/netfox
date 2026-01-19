extends VestTest

func get_suite_name() -> String:
	return "Snapshot"

func suite() -> void:
	test("apply()", func():
		# 22.46us, 367.25us, 1.44ms, 2.90ms, 54.68ms
		# 23.92us, 331.23us, 1.35ms, 2.73ms, 45.37ms
		for case in [[16, 2, 64], [128, 4, 8], [512, 4, 4], [1024, 4, 1], [16384, 4, 1]]:
			var node_count := case[0] as int
			var prop_count := case[1] as int
			var batch_size := case[2] as int

			var nodes := get_nodes(node_count)

			var snapshot := Snapshot.new(0)
			for node in nodes:
				for i in prop_count:
					var prop := "property%d" % (i + 1)
					snapshot.record_property(node, prop)

			benchmark("apply() - %dn/%dp" % [node_count, prop_count], func(__):
				snapshot.apply()
			).with_duration(1.).with_batch_size(batch_size).run()
			
			free_nodes(nodes)
		)

	test("merge()", func():
		# 30.35us, 502.14us,   2.09ms, 4.85ms, 114.49ms
		# 20.75us, 178.53us, 704.67us, 1.46ms, 31.61ms
		for case in [[16, 2, 64], [128, 4, 8], [512, 4, 4], [1024, 4, 1], [16384, 4, 1]]:
			var node_count := case[0] as int
			var prop_count := case[1] as int
			var batch_size := case[2] as int

			var nodes := get_nodes(node_count)

			var base_snapshot := Snapshot.new(0)
			var patch_snapshot := Snapshot.new(0)

			for node in nodes:
				for i in prop_count:
					var prop := "property%d" % (i + 1)
					base_snapshot.set_property(node, prop, randi())
					patch_snapshot.set_property(node, prop, randi())

			benchmark("merge() - %dn/%dp" % [node_count, prop_count], func(__):
				base_snapshot.merge(patch_snapshot)
			).with_duration(1.).with_batch_size(batch_size).run()
			
			free_nodes(nodes)
		)

func get_nodes(count: int) -> Array[TestNode]:
	var nodes := [] as Array[TestNode]
	for i in count:
		var node := TestNode.new()
		node.name += " %d" % i
		nodes.append(node)
	return nodes

func free_nodes(nodes: Array[TestNode]) -> void:
	for node in nodes:
		node.queue_free()

class TestNode extends Node:
	var property1 := randi()
	var property2 := randi()
	var property3 := randi()
	var property4 := randi()

	var property5 := randi()
	var property6 := randi()
	var property7 := randi()
	var property8 := randi()
