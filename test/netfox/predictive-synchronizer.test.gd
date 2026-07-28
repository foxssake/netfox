extends VestTest

func get_suite_name() -> String:
	return "PredictiveSynchronizer"

var root: SyncNode
var synchronizer: PredictiveSynchronizer

func before_case(__) -> void:
	NetworkMocks.set_tick(10, 10)
	root = SyncNode.new()
	root.name = "Predictive Root"

	synchronizer = PredictiveSynchronizer.new()
	synchronizer.name = "PredictiveSynchronizer"
	synchronizer.root = root
	synchronizer.state_properties = [":tracked_value"]

	root.add_child(synchronizer)
	Vest.get_tree().root.add_child.call_deferred(root)
	await root.ready

func after_case(__) -> void:
	NetworkHistoryServer.deregister(root)
	RollbackLivenessServer.deregister(root)
	root.queue_free()

	NetworkRollback._resim_from = NetworkTime.tick

func suite() -> void:
	define("spawn tick behavior", func():
		test("should seed rollback state at spawn tick", func():
			root.tracked_value = 13
			synchronizer.spawn_tick = 4

			synchronizer.process_settings()

			var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(4)
			expect_not_null(snapshot)
			expect(snapshot.has_property(root, ^"tracked_value"))
			expect_equal(snapshot.get_property(root, ^"tracked_value"), 13)
			expect_equal(NetworkHistoryServer.get_latest_state_tick_for([root], 4), 4)
		)

		test("should register liveness using spawn tick", func():
			synchronizer.spawn_tick = 6

			synchronizer.process_settings()

			expect(RollbackLivenessServer.is_alive(root, 6))
			expect_not(RollbackLivenessServer.is_alive(root, 5))
		)

		test("should reseed state and clear despawn when spawned", func():
			synchronizer.process_settings()

			synchronizer.despawn(5)
			root.tracked_value = 42
			synchronizer.spawn(7)

			var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(7)
			expect_equal(synchronizer.spawn_tick, 7)
			expect(RollbackLivenessServer.is_alive(root, 8))
			expect_not_null(snapshot)
			expect_equal(snapshot.get_property(root, ^"tracked_value"), 42)
		)

		test("should request resimulation from spawn tick", func():
			synchronizer.spawn_tick = 3
			NetworkRollback._resim_from = 12

			NetworkRollback.before_loop.emit()

			expect_equal(NetworkRollback._resim_from, 3)
		)
	)

class SyncNode extends Node:
	var tracked_value := 0

	func _rollback_tick(_dt: float, _tick: int, _is_fresh: bool) -> void:
		pass

	func _rollback_spawn() -> void:
		pass

	func _rollback_despawn() -> void:
		pass

	func _rollback_destroy() -> void:
		pass
