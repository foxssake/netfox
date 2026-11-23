extends VestTest

func get_suite_name() -> String:
	return "Snapshot hot path"

const NODE_COUNT := 128
const PROP_COUNT := 4
const HISTORY := 64

func suite() -> void:
	test("history buffer push", func():
		var buffer := _HistoryBuffer.new(HISTORY)
		var value := _ObjectSnapshot.new(null)
		var tick := 0
		benchmark("push()", func(__):
			buffer.set_at(tick, value)
			tick += 1
			if tick >= HISTORY * 8:
				buffer = _HistoryBuffer.new(HISTORY)
				tick = 0
		).with_duration(0.25).with_batch_size(256).run()
	)

	test("object snapshot apply", func():
		var node := HotNode.new()
		var snapshot := _ObjectSnapshot.new(node)
		for i in PROP_COUNT:
			snapshot.set_value(NodePath("property%d" % (i + 1)), i)
		benchmark("apply()", func(__):
			snapshot.apply()
		).with_duration(0.25).with_batch_size(64).run()
		node.free()
	)

	test("record and restore", func():
		var nodes := _make_nodes(NODE_COUNT)
		var props := []
		for i in PROP_COUNT:
			props.append(NodePath("property%d" % (i + 1)))

		for node in nodes:
			Vest.get_tree().root.add_child(node)
			for property in props:
				NetworkHistoryServer.register_rollback_state(node, property)

		var tick := 0
		benchmark("record sequential", func(__):
			for node in nodes:
				node.property1 += 1
			NetworkHistoryServer._record_rollback_state(tick)
			tick += 1
		).with_duration(0.25).with_batch_size(1).run()

		benchmark("restore latest", func(__):
			NetworkHistoryServer._restore_rollback_state(tick - 1)
		).with_duration(0.25).with_batch_size(4).run()

		for node in nodes:
			NetworkHistoryServer.deregister(node)
			node.queue_free()
	)

func _make_nodes(count: int) -> Array:
	var nodes := []
	for i in count:
		var node := HotNode.new()
		node.name = "Hot %d" % i
		nodes.append(node)
	return nodes

class HotNode extends Node:
	var property1 := 1
	var property2 := 2
	var property3 := 3
	var property4 := 4
