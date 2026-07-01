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
		test("should not publish completeness without owned state", func():
			var remote_node := await get_node()
			remote_node.set_multiplayer_authority(2)

			NetworkMocks.set_network_tick(11)
			servers.synchronization_server().register_rollback_input(remote_node, _INPUT_PROPERTY)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), -1)

			remote_node.queue_free()
		)
	)

	define("register_rollback_state()", func():
		test("should compute the local latest complete tick for owned state", func():
			var state_node := await get_node()

			NetworkMocks.set_network_tick(11)
			servers.synchronization_server().register_rollback_state(state_node, _INPUT_PROPERTY)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 11)

			state_node.queue_free()
		)
	)

	define("local input completeness", func():
		test("should expect input from peers controlling owned state", func():
			var state_node := await get_node()
			var input_node := await get_node()
			input_node.set_multiplayer_authority(2)

			servers.simulation_server().register_rollback_input_for(state_node, input_node)
			NetworkMocks.set_network_tick(11)
			servers.synchronization_server().register_rollback_input(input_node, _INPUT_PROPERTY)
			servers.synchronization_server().register_rollback_state(state_node, _INPUT_PROPERTY)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 10)

			state_node.queue_free()
			input_node.queue_free()
		)

		test("should advance once the expected remote input arrives", func():
			var state_node := await get_node()
			var input_node := await get_node()
			input_node.set_multiplayer_authority(2)

			servers.simulation_server().register_rollback_input_for(state_node, input_node)
			NetworkMocks.set_network_tick(11)
			servers.synchronization_server().register_rollback_input(input_node, _INPUT_PROPERTY)
			servers.synchronization_server().register_rollback_state(state_node, _INPUT_PROPERTY)

			NetworkMocks.set_network_tick(20)
			servers.synchronization_server()._track_remote_input(2, _Snapshot.of(14, [[input_node, _INPUT_PROPERTY, Vector3.ZERO]], [input_node]))

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 14)

			state_node.queue_free()
			input_node.queue_free()
		)
	)

	define("combined input completeness", func():
		test("should wait for updates from other state authorities", func():
			var local_state_node := await get_node()
			var remote_state_node := await get_node()
			remote_state_node.set_multiplayer_authority(2)

			NetworkMocks.set_network_tick(20)
			servers.synchronization_server().register_rollback_state(local_state_node, _INPUT_PROPERTY)
			servers.synchronization_server().register_rollback_state(remote_state_node, _INPUT_PROPERTY)

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), -1)

			servers.synchronization_server()._handle_inputs_complete(2, _u32_data(17))

			expect_equal(servers.synchronization_server().get_latest_inputs_complete_tick(), 17)

			local_state_node.queue_free()
			remote_state_node.queue_free()
		)
	)

func get_node() -> Node3D:
	var node := Node3D.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node


func _u32_data(value: int) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u32(value)
	return buffer.data_array
