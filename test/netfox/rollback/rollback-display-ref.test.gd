extends VestTest

const _HEALTH_PROPERTY: NodePath = ^"health"


func suite() -> void:
	test(
		"Returns current value when rollback inputs are incomplete",
		func() -> void:
			var reference: RollbackDisplayRef
			var node: TestNode = await _create_test_node()
			node.health = 17
			reference = RollbackDisplayRef.new(node, _HEALTH_PROPERTY)

			_with_latest_inputs_complete_tick(
				-1,
				func() -> void:
					expect_equal(reference.get_value(), 17)
			)

			node.queue_free()
	)

	test(
		"Returns seeded rollback value when history exists",
		func() -> void:
			var reference: RollbackDisplayRef
			var node: TestNode = await _create_test_node()
			NetworkMocks.set_network_tick(0)
			node.health = 10
			reference = RollbackDisplayRef.new(node, _HEALTH_PROPERTY)

			NetworkHistoryServer.register_rollback_state(node, _HEALTH_PROPERTY)
			NetworkHistoryServer._merge_rollback_state(
				_Snapshot.of(0, [[node, _HEALTH_PROPERTY, 10]], [node])
			)
			node.health = 25

			_with_latest_inputs_complete_tick(
				0,
				func() -> void:
					expect_equal(reference.get_value(), 10)
			)

			NetworkHistoryServer.deregister(node)
			node.queue_free()
	)


func get_suite_name() -> String:
	return "RollbackDisplayRef"


func _create_test_node() -> TestNode:
	var node := TestNode.new()
	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready
	return node


func _with_latest_inputs_complete_tick(tick: int, callback: Callable) -> void:
	var previous_tick: int = NetworkSynchronizationServer.get_latest_inputs_complete_tick()
	NetworkSynchronizationServer._set_latest_inputs_complete_tick(tick)
	callback.call()
	NetworkSynchronizationServer._set_latest_inputs_complete_tick(previous_tick)


class TestNode:
	extends Node

	var health: int = 0
