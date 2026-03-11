extends VestTest

func get_suite_name() -> String:
	return "NetworkRollback"

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
