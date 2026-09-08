extends VestTest

# Perf coverage for rollback record/restore properties

func get_suite_name() -> String:
	return "NetworkHistoryServer (rollback state)"

func suite():
	for count in [16, 256, 4096]:
		test("%d nodes x 4 properties" % count, func():
			var nodes := await get_nodes(count)
			for node in nodes:
				NetworkHistoryServer.register_rollback_state(node, "position")
				NetworkHistoryServer.register_rollback_state(node, "rotation")
				NetworkHistoryServer.register_rollback_state(node, "velocity")
				NetworkHistoryServer.register_rollback_state(node, "health")

			NetworkHistoryServer._record_rollback_state(0)

			benchmark("record()", func(__):
				NetworkHistoryServer._record_rollback_state(0)
			).with_duration(1.).with_batch_size(16).run()

			benchmark("restore()", func(__):
				NetworkHistoryServer._restore_rollback_state(0)
			).with_duration(1.).with_batch_size(16).run()

			for node in nodes:
				NetworkHistoryServer.deregister(node)
			free_nodes(nodes)
		)

func get_nodes(count: int) -> Array[Node]:
	var nodes := [] as Array[Node]

	for i in count:
		var node := StateNode.new()
		node.name = "Node %d" % i
		nodes.append(node)
		Vest.get_tree().root.add_child.call_deferred(node)

	for node in nodes:
		await node.ready

	return nodes

func free_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		node.queue_free()

class StateNode extends Node3D:
	var velocity := Vector3.ZERO
	var health := 100
