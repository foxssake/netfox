extends VestTest

func get_suite_name() -> String:
	return "RollbackSimulationServer"

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func suite() -> void:
	define("is_predicting()", func():
		test("should predict non-owned node", func():
			var state_node := await get_node()
			var input_node := await get_node()
			var input_snapshot := Snapshot.of(1, [[input_node, "name", "Input"]], [])

			state_node.set_multiplayer_authority(2)
			RollbackSimulationServer.register_input_for(state_node, input_node)

			expect(RollbackSimulationServer.is_predicting(input_snapshot, state_node))
		)

		test("should predict owned node without input", func():
			var input_snapshot := Snapshot.new(0)
			var state_node := await get_node()
			var input_node := await get_node()

			RollbackSimulationServer.register_input_for(state_node, input_node)

			expect(RollbackSimulationServer.is_predicting(input_snapshot, state_node))
		)

		test("should predict non-owned inputless", func():
			var input_snapshot := Snapshot.new(0)
			var state_node := await get_node()

			state_node.set_multiplayer_authority(2)

			expect(RollbackSimulationServer.is_predicting(input_snapshot, state_node))
		)

		test("should not predict owned inputless", func():
			var input_snapshot := Snapshot.new(0)
			var state_node := await get_node()

			expect_not(RollbackSimulationServer.is_predicting(input_snapshot, state_node))
		)

		test("should not predict owned with input", func():
			var state_node := await get_node()
			var input_node := await get_node()
			var input_snapshot := Snapshot.of(1, [[input_node, "name", "Input"]], [input_node])

			RollbackSimulationServer.register_input_for(state_node, input_node)

			expect_not(RollbackSimulationServer.is_predicting(input_snapshot, state_node))
		)
	)

	define("get_nodes_to_simulate()", func():
		test("should not simulate without input", func():
			var node := RewindableNode.new()
			var input_node := Node.new()
			
			var server := _RollbackSimulationServer.new()
			server.register(node._rollback_tick)
			server.register_input_for(node, input_node)
			
			var snapshot := Snapshot.new(1)
			
			expect_empty(server.get_nodes_to_simulate(snapshot))
		)
		
		test("should simulate with input", func():
			var node := RewindableNode.new()
			var input_node := Node.new()
			
			var server := _RollbackSimulationServer.new()
			server.register(node._rollback_tick)
			server.register_input_for(node, input_node)
			
			var snapshot := Snapshot.new(1)
			snapshot.set_property(input_node, "editor_description", "Test input node")
			snapshot.set_auth(input_node, true)
			
			expect_equal(server.get_nodes_to_simulate(snapshot), [node])
		)
		
		test("should simulate mutated", func():
			var node := RewindableNode.new()
			var input_node := Node.new()
			
			var server := _RollbackSimulationServer.new()
			server.register(node._rollback_tick)
			server.register_input_for(node, input_node)
			
			var snapshot := Snapshot.new(1)
			NetworkRollback.mutate(node)
			
			expect_equal(server.get_nodes_to_simulate(snapshot), [node])
		)
	)

class RewindableNode extends Node:
	func _rollback_tick(_dt, _t, _if) -> void:
		pass

func get_node() -> Node:
	var node := Node.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready

	return node
