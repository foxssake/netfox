extends VestTest

const _INPUT_PROPERTY: NodePath = ^"position"

func get_suite_name() -> String:
	return "NetworkSynchronizationServer"

var servers: TestingServers

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkMocks.set_network_tick(0)
	servers = await TestingServers.create()

func after_case(__):
	servers.queue_free()

func suite() -> void:
	define("get_latest_inputs_complete_tick()", func():
		test("should default to -1", func():
			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), -1)
		)
	)

	define("register_rollback_input()", func():
		test("should recompute the latest complete tick", func():
			var remote_node := await get_node()
			remote_node.set_multiplayer_authority(2)

			NetworkMocks.set_network_tick(11)
			servers.synchronization_server().register_rollback_input(remote_node, _INPUT_PROPERTY)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 11)

			remote_node.queue_free()
		)
	)

	define("deregister_rollback_input()", func():
		test("should refresh the latest complete tick after removal", func():
			var remote_node := await get_node()
			remote_node.set_multiplayer_authority(2)

			NetworkMocks.set_network_tick(11)
			servers.synchronization_server().register_rollback_input(remote_node, _INPUT_PROPERTY)

			NetworkMocks.set_network_tick(15)
			servers.synchronization_server().deregister_rollback_input(remote_node, _INPUT_PROPERTY)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 15)

			remote_node.queue_free()
		)
	)

	define("deregister()", func():
		test("should refresh the latest complete tick after deregistering a node", func():
			var remote_node := await get_node()
			remote_node.set_multiplayer_authority(2)

			NetworkMocks.set_network_tick(9)
			servers.synchronization_server().register_rollback_input(remote_node, _INPUT_PROPERTY)

			NetworkMocks.set_network_tick(12)
			servers.synchronization_server().deregister(remote_node)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 12)

			remote_node.queue_free()
		)
	)

func get_node() -> Node3D:
	var node := Node3D.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node
