extends VestTest

func get_suite_name() -> String:
	return "NetworkHistoryServer"

var servers: TestingServers
var nodes: Array[Node3D] = []

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkMocks.set_network_tick(10)
	servers = await TestingServers.create()

func after_case(__):
	servers.queue_free()
	for node in nodes:
		node.queue_free()
	nodes.clear()

func suite() -> void:
	define("_merge_rollback_state()", func():
		test("should overwrite auth state for same tick", func():
			var node := await get_node("OverwriteAuth")
			var history_server := servers.history_server()

			var baseline := _Snapshot.of(0, [
				[node, "position", Vector3.ZERO]
			], [node])
			var initial := _Snapshot.of(1, [
				[node, "position", Vector3.ZERO]
			], [node])
			var corrected := _Snapshot.of(1, [
				[node, "position", Vector3.ONE]
			], [node])

			history_server._merge_rollback_state(baseline)
			history_server._merge_rollback_state(initial)
			expect_true(history_server._merge_rollback_state(corrected))

			var current := history_server._get_rollback_state_snapshot(1)
			expect_equal(current, corrected)

			var diff := _Snapshot.make_patch(history_server._get_rollback_state_snapshot(0), current)
			expect_equal(diff, _Snapshot.of(1, [
				[node, "position", Vector3.ONE]
			], [node]))
		)
		test("should truncate newer auth history for merged subject only", func():
			var rewound_node := await get_node("Rewound")
			var history_server := servers.history_server()

			history_server.register_rollback_state(rewound_node, "position")

			rewound_node.position = Vector3(1, 0, 0)
			history_server._record_rollback_state(5)

			rewound_node.position = Vector3(2, 0, 0)
			history_server._record_rollback_state(6)

			var authoritative_snapshot := _Snapshot.of(5, [
				[rewound_node, "position", Vector3(100, 0, 0)]
			], [rewound_node])

			expect_equal(history_server.get_latest_state_tick_for([rewound_node], NetworkTime.tick), 6)
			history_server._merge_rollback_state(authoritative_snapshot)
			expect_equal(history_server.get_latest_state_tick_for([rewound_node], NetworkTime.tick), 5)
		)
	)

func get_node(name: String) -> Node3D:
	var node := Node3D.new()
	node.name = name
	nodes.append(node)

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready

	return node
