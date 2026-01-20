extends VestTest

func get_suite_name() -> String:
	return "NetworkSynchronizationServer"

var servers: TestingServers

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	servers = await TestingServers.create()

	servers.synchronization_server()._rb_enable_input_broadcast = true # Force input broadcast

func after_case(__):
	servers.queue_free()

func suite() -> void:
	define("synchronize_input()", func():
		test("should submit owned", func():
			var owned_node := await get_node()
			var other_node := await get_node()

			other_node.set_multiplayer_authority(2)

			servers.history_server().register_input(owned_node, "position")
			servers.history_server().register_input(other_node, "position")

			servers.synchronization_server().register_input(owned_node, "position")
			servers.synchronization_server().register_input(other_node, "position")

			servers.history_server().record_input(0)
			servers.synchronization_server().synchronize_input(0)

			skip() # TODO: Somehow setup a live client-server connection
		)
	)

	define("synchronize_state()", func():
		test("should submit owned", func():
			skip()
		)
	)

	define("synchronize_sync_state()", func():
		test("should submit owned", func():
			skip()
		)
	)

func get_node(name: String = "") -> Node3D:
	var node := Node3D.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready
	if name: node.name = name

	return node
