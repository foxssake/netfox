extends VestTest

func get_suite_name() -> String:
	return "NetworkHistoryServer"

var servers: TestingServers

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	servers = await TestingServers.create()

func after_case(__):
	servers.queue_free()

func suite() -> void:
	define("_merge_rollback_state()", func():
		test("should overwrite auth state for same tick", func():
			var node := await get_node()
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
	)

func get_node() -> Node3D:
	var node := Node3D.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready

	return node
