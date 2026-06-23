extends VestTest

func get_suite_name() -> String:
	return "RollbackSynchronizer"

var spawn_root: SpawnAwareRollbackNode
var spawn_rbs: RollbackSynchronizer

func after_case(__) -> void:
	if is_instance_valid(spawn_root):
		NetworkHistoryServer.deregister(spawn_root)
		RollbackLivenessServer.deregister(spawn_root)
		spawn_root.queue_free()

	NetworkRollback._resim_from = NetworkTime.tick

func suite():
	test("Nested RollbackSynchronizer support", func():
		# Setup node layout:
		# 	primary_root/
		# 	├── primary_rbs
		# 	└── secondary_root/
		# 	    └── secondary_rbs

		var primary_root := RollbackAware.new(); primary_root.name = "Primary Root"
		var primary_rbs := RollbackSynchronizer.new(); primary_rbs.name = "Primary RBS"
		var secondary_root := RollbackAware.new(); secondary_root.name = "Secondary Root"
		var secondary_rbs := RollbackSynchronizer.new(); secondary_rbs.name = "Secondary RBS"

		primary_root.add_child(primary_rbs)
		primary_root.add_child(secondary_root)
		secondary_root.add_child(secondary_rbs)

		primary_rbs.root = primary_root
		secondary_rbs.root = secondary_root

		Vest.get_tree().root.add_child.call_deferred(primary_root)
		await primary_root.ready

		# Pick up managed nodes
		primary_rbs.process_settings()
		secondary_rbs.process_settings()

		# Check managed nodes
		expect_equal(primary_rbs._sim_nodes, [primary_root])
		expect_equal(secondary_rbs._sim_nodes, [secondary_root])

		print("Node tree:")
		primary_root.print_tree_pretty()
		print("Primary managed: %s" % [primary_rbs._sim_nodes])
		print("Secondary managed: %s" % [secondary_rbs._sim_nodes])

		# Cleanup
		primary_root.queue_free()
	)

	define("spawn tick behavior", func():
		test("should seed initial rollback state at spawn tick", func():
			var setup := await create_spawn_synchronizer(4, 21)
			var root := setup[0] as SpawnAwareRollbackNode
			var rbs := setup[1] as RollbackSynchronizer

			rbs.process_authority()

			var snapshot := NetworkHistoryServer._get_rollback_state_snapshot(4)
			expect_not_null(snapshot)
			expect(snapshot.has_property(root, ^"tracked_value"))
			expect_equal(snapshot.get_property(root, ^"tracked_value"), 21)
			expect_equal(NetworkHistoryServer.get_latest_state_tick_for([root], 4), 4)
		)

		test("should register liveness using spawn tick", func():
			var setup := await create_spawn_synchronizer(6, 0)
			var root := setup[0] as SpawnAwareRollbackNode
			var rbs := setup[1] as RollbackSynchronizer

			rbs.process_settings()

			expect(RollbackLivenessServer.is_alive(root, 6))
			expect_not(RollbackLivenessServer.is_alive(root, 5))
		)

		test("should request resimulation from spawn tick", func():
			var setup := await create_spawn_synchronizer(3, 0)
			var rbs := setup[1] as RollbackSynchronizer
			NetworkRollback._resim_from = 12

			rbs._on_before_loop()

			expect_equal(NetworkRollback._resim_from, 3)
		)
	)

	# Messy to set up, keeping cases for later
	define("Input age and predicting", func():
		test("should return -1 on no input", func(): todo())
		test("should return 0 on recent input", func(): todo())
		test("should return positive on old input", func(): todo())
	)

	define("get_last_known_input()", func():
		test("should return -1 for no input", func(): todo())
		test("should return latest", func(): todo())
	)

	define("get_last_known_state()", func():
		test("should return -1 for no state", func(): todo())
		test("should return latest", func(): todo())
	)

class RollbackAware extends Node:
	func _rollback_tick(_dt: float, _t: int, _if: int) -> void:
		pass

	func _to_vest():
		return _to_string()

	func _to_string() -> String:
		return "RollbackAware:" + name

func create_spawn_synchronizer(spawn_tick: int, tracked_value: int) -> Array:
	spawn_root = SpawnAwareRollbackNode.new()
	spawn_root.name = "Spawn Root"
	spawn_root.tracked_value = tracked_value

	spawn_rbs = RollbackSynchronizer.new()
	spawn_rbs.name = "Spawn RBS"
	spawn_rbs.root = spawn_root
	spawn_rbs.state_properties = [":tracked_value"]
	spawn_rbs.spawn_tick = spawn_tick

	spawn_root.add_child(spawn_rbs)

	Vest.get_tree().root.add_child.call_deferred(spawn_root)
	await spawn_root.ready

	return [spawn_root, spawn_rbs]

class SpawnAwareRollbackNode extends Node:
	var tracked_value := 0

	func _rollback_tick(_dt: float, _t: int, _if: int) -> void:
		pass

	func _rollback_spawn() -> void:
		pass

	func _rollback_despawn() -> void:
		pass

	func _rollback_destroy() -> void:
		pass
