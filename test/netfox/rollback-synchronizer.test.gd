extends VestTest

func get_suite_name() -> String:
	return "RollbackSynchronizer"

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
		
		primary_rbs.owner = primary_root
		secondary_root.owner = primary_root
		secondary_rbs.owner = primary_root
		
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
