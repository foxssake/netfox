extends VestTest

func get_suite_name() -> String:
	return "RollbackSimulationServer"

func suite() -> void:
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
		snapshot.set_property(input_node, "editor_description", "Test input node", true)
		
		expect_equal(server.get_nodes_to_simulate(snapshot), [node])
	)

class RewindableNode extends Node:
	func _rollback_tick(_dt, _t, _if) -> void:
		pass
