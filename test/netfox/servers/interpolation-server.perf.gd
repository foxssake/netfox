extends VestTest

func get_suite_name() -> String:
	return "InterpolationServer"

var interpolation_server: _InterpolationServer
var idx := 0

func before_case(__):
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	interpolation_server = _InterpolationServer.new()
	Vest.get_tree().root.add_child.call_deferred(interpolation_server)
	await interpolation_server.ready

func after_case(__):
	interpolation_server.queue_free()

func suite():
	for count in [16, 128, 1024]:
		test("%d groups with single property" % count, func():
			var nodes = await get_nodes(count)
			var group_ids := []

			for i in count:
				group_ids.append(i)

			idx = 0
			benchmark("register()", func(__):
				var node = nodes[idx]
				var group_id = group_ids[idx]
				node.position = Vector3(0, 0, 0)
				interpolation_server.register_interpolation_group(
					group_id, node, [":position"], true, true
				)
				idx += 1
			).with_iterations(count).with_batch_size(count).run()

			for i in count:
				nodes[i].position = Vector3(0, 0, 0)
				interpolation_server.push_state(group_ids[i])
				nodes[i].position = Vector3(10, 10, 10)
				interpolation_server.push_state(group_ids[i])

			idx = 0
			benchmark("push_state()", func(__):
				var group_id = group_ids[idx % count]
				interpolation_server.push_state(group_id)
				idx += 1
			).with_duration(1.0).with_batch_size(64).run()

			idx = 0
			benchmark("interpolate()", func(__):
				var group_id = group_ids[idx % count]
				interpolation_server.interpolate(group_id, 0.5)
				idx += 1
			).with_duration(1.0).with_batch_size(64).run()

			idx = 0
			benchmark("deregister()", func(__):
				var group_id = group_ids[idx]
				interpolation_server.deregister_interpolation_group(group_id)
				idx += 1
			).with_iterations(count).with_batch_size(count).run()

			# Free nodes
			free_nodes(nodes)
		)

	for count in [16, 128, 1024]:
		test("%d groups with multiple properties" % count, func():
			var nodes = await get_nodes(count)
			var group_ids := []

			for i in count:
				group_ids.append(10000 + i)

			idx = 0
			benchmark("register() multi-prop", func(__):
				var node = nodes[idx]
				var group_id = group_ids[idx]
				node.position = Vector3(0, 0, 0)
				node.rotation = Vector3(0, 0, 0)
				node.scale = Vector3(1, 1, 1)
				interpolation_server.register_interpolation_group(
					group_id, node, [":position", ":rotation", ":scale"], true, true
				)
				idx += 1
			).with_iterations(count).with_batch_size(count).run()

			# Setup initial states
			for i in count:
				nodes[i].position = Vector3(0, 0, 0)
				nodes[i].rotation = Vector3(0, 0, 0)
				nodes[i].scale = Vector3(1, 1, 1)
				interpolation_server.push_state(group_ids[i])
				nodes[i].position = Vector3(10, 10, 10)
				nodes[i].rotation = Vector3(1, 1, 1)
				nodes[i].scale = Vector3(2, 2, 2)
				interpolation_server.push_state(group_ids[i])

			idx = 0
			benchmark("push_state() multi-prop", func(__):
				var group_id = group_ids[idx % count]
				interpolation_server.push_state(group_id)
				idx += 1
			).with_duration(1.0).with_batch_size(64).run()

			idx = 0
			benchmark("interpolate() multi-prop", func(__):
				var group_id = group_ids[idx % count]
				interpolation_server.interpolate(group_id, 0.5)
				idx += 1
			).with_duration(1.0).with_batch_size(64).run()

			idx = 0
			benchmark("deregister() multi-prop", func(__):
				var group_id = group_ids[idx]
				interpolation_server.deregister_interpolation_group(group_id)
				idx += 1
			).with_iterations(count).with_batch_size(count).run()

			# Free nodes
			free_nodes(nodes)
		)

func get_nodes(count: int) -> Array[Node3D]:
	var nodes := [] as Array[Node3D]

	for i in count:
		var node := Node3D.new()
		node.name = "Node %d" % i
		nodes.append(node)
		Vest.get_tree().root.add_child.call_deferred(node)

	for node in nodes:
		await node.ready

	return nodes

func free_nodes(nodes: Array[Node3D]) -> void:
	for node in nodes:
		node.queue_free()
