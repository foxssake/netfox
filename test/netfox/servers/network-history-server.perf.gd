extends VestTest

func get_suite_name() -> String:
	return "NetworkHistoryServer"

var idx := 0

func suite():
	for count in [16, 1024, 16384]:
		# register / record / restore / deregister
		# *2.06us/235.37us/*46.01us/*1.37us, 14.05us/14.73ms/1.08ms/6.56us, 207.84us/234.73ms/23.18ms/88.84us
		# *2.19us/77.97us/*23.46us/*3.07us,   1.73us/ 4.55ms/1.83ms/1.48us,   2.15us/ 81.64ms/45.45ms/ 1.57us
		test("%d nodes" % count, func():
			# Create nodes
			var nodes := await get_nodes(count)
			
			# Register nodes
			idx = 0
			benchmark("register()", func(__):
				NetworkHistoryServer.register_state(nodes[idx], "name")
				idx += 1
			).with_iterations(count).with_batch_size(count).run()
			
			# Record
			benchmark("record()", func(__):
				NetworkHistoryServer.record_state(0)
			).with_duration(1.).with_batch_size(16).run()
			
			# Restore
			benchmark("restore()", func(__):
				NetworkHistoryServer.restore_rollback_state(0)
			).with_duration(1.).with_batch_size(16).run()
			
			# Deregister nodes
			idx = 0
			benchmark("deregister()", func(__):
				NetworkHistoryServer.deregister_state(nodes[idx], "name")
				idx += 1
			).with_iterations(count).with_batch_size(count).run()
			
			# Free nodes
			free_nodes(nodes)
		)

func get_nodes(count: int) -> Array[Node]:
	var nodes := [] as Array[Node]

	for i in count:
		var node := Node.new()
		node.name = "Node %d" % i
		nodes.append(node)
		Vest.get_tree().root.add_child.call_deferred(node)

	for node in nodes:
		await node.ready

	return nodes

func free_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		node.queue_free()
