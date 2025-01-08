extends VestTest

func get_suite_name() -> String:
	return "NetworkRollback"

# NOTE: When instantiating _NetworkRollback, Godot tries to resolve NetworkTime,
# which it can't in CI. Until that's figured out and/or netfox moves away from 
# autoloads, these tests will have to be skipped.

#var network_rollback: _NetworkRollback
#var mutated_node: Node
#
#func before():
#	mutated_node = Node.new()
#	add_child(mutated_node)
#
#func before_each():
#	network_rollback = _NetworkRollback.new()
#
##region Mutate
#func test_should_be_mutated_after():
#	# Given
#	network_rollback.mutate(mutated_node, 8)
#
#	# When + Then
#	expect(network_rollback.is_mutated(mutated_node, 10))
#	expect_not(network_rollback.is_just_mutated(mutated_node, 10))
#
#func test_should_just_be_mutated():
#	# Given
#	network_rollback.mutate(mutated_node, 8)
#
#	# When + Then
#	expect(network_rollback.is_mutated(mutated_node, 8))
#	expect(network_rollback.is_just_mutated(mutated_node, 8))
#
#func test_should_not_be_mutated_after():
#	# Given
#	network_rollback.mutate(mutated_node, 8)
#
#	# When + Then
#	expect_not(network_rollback.is_mutated(mutated_node, 4))
#	expect_not(network_rollback.is_just_mutated(mutated_node, 4))
#
#func test_unknown_should_not_be_mutated():
#	# Given nothing
#
#	# Then
#	expect_not(network_rollback.is_mutated(mutated_node, 8))
#	expect_not(network_rollback.is_just_mutated(mutated_node, 8))
##endregion
