extends VestTest

func get_suite_name() -> String:
	return "NetworkRollback"

# NOTE: When instantiating _NetworkRollback, Godot tries to resolve NetworkTime,
# which it can't in CI. Until that's figured out and/or netfox moves away from 
# autoloads, these tests will have to be skipped.

var network_rollback: _NetworkRollback
var mutated_node: Node

func before_case(__):
	network_rollback = _NetworkRollback.new()
	mutated_node = Node.new()

func after_case(__):
	network_rollback.queue_free()
	mutated_node.queue_free()

func suite() -> void:
	define("mutate()", func():
		test("should be mutated after", func():
			# Given
			network_rollback.mutate(mutated_node, 8)

			# When + Then
			expect(network_rollback.is_mutated(mutated_node, 10))
			expect_not(network_rollback.is_just_mutated(mutated_node, 10))
		)
		
		test("should just be mutated", func():
			# Given
			network_rollback.mutate(mutated_node, 8)

			# When + Then
			expect(network_rollback.is_mutated(mutated_node, 8))
			expect(network_rollback.is_just_mutated(mutated_node, 8))
		)
		
		test("should not be mutated after", func():
			# Given
			network_rollback.mutate(mutated_node, 8)

			# When + Then
			expect_not(network_rollback.is_mutated(mutated_node, 4))
			expect_not(network_rollback.is_just_mutated(mutated_node, 4))
		)
		
		test("unknown should not be mutated", func():
			# Given nothing

			# Then
			expect_not(network_rollback.is_mutated(mutated_node, 8))
			expect_not(network_rollback.is_just_mutated(mutated_node, 8))
		)
	)
	
	define("input submission", func():
		test("should have input after submit", func():
			# Given
			network_rollback.register_input_submission(mutated_node, 2)
			
			# Then
			expect(network_rollback.has_input_for_tick(mutated_node, 2), "Node should have input!")
			expect(network_rollback.has_input_for_tick(mutated_node, 1), "Node should have future input!")
			expect_not(network_rollback.has_input_for_tick(mutated_node, 3), "Node shouldn't yet have input!")
		)
		
		test("should return latest input tick", func():
			# Given
			network_rollback.register_input_submission(mutated_node, 2)
			
			# Then
			expect_equal(network_rollback.get_latest_input_tick(mutated_node), 2)
		)
		
		test("should return no input tick", func():
			# Given nothing
			# Then
			expect_equal(network_rollback.get_latest_input_tick(mutated_node), -1)
		)
	)
