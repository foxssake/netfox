extends VestTest

func get_suite_name() -> String:
	return "NetworkIdentityServer"

var command_server: _NetworkCommandServer
var identity_server: _NetworkIdentityServer

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	
	command_server = _NetworkCommandServer.new()
	identity_server = _NetworkIdentityServer.new(command_server)

	Vest.get_tree().root.add_child.call_deferred(command_server)
	Vest.get_tree().root.add_child.call_deferred(identity_server)

	await command_server.ready
	await identity_server.ready

func after_case(__):
	identity_server.queue_free()
	command_server.queue_free()

func suite() -> void:
	define("resolve_reference()", func():
		# 6.04us/7.08us, 26.75us/32.29us, 211.05us/240.66us, 4.55ms/4.35ms
		# ??/3.69us, ??/3.74us, ??/3.81us, ??/3.99us
		# 2.73us/3.63us, 2.73us/3.72us, 2.68us/3.68us, 2.91us/3.95us
		for case in [[16, 512], [128, 512], [1024, 512], [16384, 512]]:
			var count := case[0] as int
			var batch := case[1] as int

			# Run benchmarks
			test("resolve %d nodes" % count, func():
				# Setup nodes
				var nodes := [] as Array[Node]
				for i in count:
					var node := Node.new()
					node.name = "Node %d" % i
					nodes.append(node)
					Vest.get_tree().root.add_child.call_deferred(node)

				# Wait for nodes to be in tree and register
				for node in nodes:
					await node.ready
					identity_server.register_node(node)

				benchmark("resolve by ID", func(__):
					var id := (randi() % count) as int
					var reference := _NetworkIdentityServer.NetworkIdentityReference.of_id(id)
					identity_server.resolve_reference(1, reference, false)
				).with_batch_size(batch).with_duration(1.).run()

				benchmark("resolve by name", func(__):
					var id := (randi() % count) as int
					var reference := _NetworkIdentityServer.NetworkIdentityReference.of_full_name("/root/Node %d" % id)
					identity_server.resolve_reference(1, reference, false)
				).with_batch_size(batch).with_duration(1.).run()

				# Free nodes
				for node in nodes:
					node.queue_free()
			)
	)
