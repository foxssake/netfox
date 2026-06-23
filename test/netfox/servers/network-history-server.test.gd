extends VestTest

func get_suite_name() -> String:
	return "NetworkHistoryServer"

var servers: TestingServers
var subject: StateNode

func before_case(__) -> void:
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkMocks.set_tick(0, 0)
	servers = await TestingServers.create()
	subject = await create_subject()

func after_case(__) -> void:
	servers.queue_free()
	NetworkHistoryServer.deregister(subject)
	RollbackLivenessServer.deregister(subject)
	subject.queue_free()

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
	define("seed_rollback_state()", func():
		test("should create a snapshot at spawn tick", func():
			subject.tracked_value = 42
			NetworkHistoryServer.register_rollback_state(subject, ^"tracked_value")

			NetworkHistoryServer.seed_rollback_state(subject, 5)

			var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(5)
			expect_not_null(snapshot)
			expect(snapshot.has_property(subject, ^"tracked_value"))
			expect_equal(snapshot.get_property(subject, ^"tracked_value"), 42)
			expect_equal(NetworkHistoryServer.get_latest_state_tick_for([subject], 5), 5)
		)

		test("should mark local authority as auth", func():
			NetworkHistoryServer.register_rollback_state(subject, ^"tracked_value")

			NetworkHistoryServer.seed_rollback_state(subject, 7)

			var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(7)
			expect_not_null(snapshot)
			expect(snapshot.is_auth(subject))
		)

		test("should mark remote authority as non-auth", func():
			subject.set_multiplayer_authority(2)
			NetworkHistoryServer.register_rollback_state(subject, ^"tracked_value")

			NetworkHistoryServer.seed_rollback_state(subject, 7)

			var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(7)
			expect_not_null(snapshot)
			expect_not(snapshot.is_auth(subject))
		)

		test("should not create history before spawn tick", func():
			NetworkHistoryServer.register_rollback_state(subject, ^"tracked_value")

			NetworkHistoryServer.seed_rollback_state(subject, 6)

			expect_equal(NetworkHistoryServer.get_latest_state_tick_for([subject], 5), -1)
		)
	)

	define("_record_rollback_state()", func():
		test("should skip subjects not alive at previous tick", func():
			subject.tracked_value = 10
			NetworkHistoryServer.register_rollback_state(subject, ^"tracked_value")
			RollbackLivenessServer.register(
				subject,
				subject._rollback_spawn,
				subject._rollback_despawn,
				subject._rollback_destroy,
				5
			)
			NetworkHistoryServer.seed_rollback_state(subject, 5)
			subject.tracked_value = 99

			NetworkHistoryServer._record_rollback_state(5)

			var spawn_snapshot := NetworkHistoryServer._get_rollback_state_snapshot(5)
			expect_not_null(spawn_snapshot)
			expect_equal(spawn_snapshot.get_property(subject, ^"tracked_value"), 10)
			expect_equal(NetworkHistoryServer.get_latest_state_tick_for([subject], 5), 5)

			subject.tracked_value = 11
			NetworkHistoryServer._record_rollback_state(6)

			var post_spawn_snapshot := NetworkHistoryServer._get_rollback_state_snapshot(6)
			expect_not_null(post_spawn_snapshot)
			expect(post_spawn_snapshot.has_property(subject, ^"tracked_value"))
			expect_equal(post_spawn_snapshot.get_property(subject, ^"tracked_value"), 11)
			expect_equal(NetworkHistoryServer.get_latest_state_tick_for([subject], 6), 6)
		)
	)

func create_subject() -> StateNode:
	var node := StateNode.new()
	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node

class StateNode extends Node:
	var tracked_value := 0
	var spawns := 0
	var despawns := 0
	var destroyed := false

	func _rollback_spawn() -> void:
		spawns += 1

	func _rollback_despawn() -> void:
		despawns += 1

	func _rollback_destroy() -> void:
		destroyed = true

func get_node() -> Node3D:
	var node := Node3D.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready

	return node
