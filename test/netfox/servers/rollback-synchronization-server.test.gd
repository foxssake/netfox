extends VestTest

func get_suite_name() -> String:
	return "RollbackSynchronizationServer"

func suite():
	test("diff state", func():
		var node := Node3D.new()
		Vest.get_tree().root.add_child.call_deferred(node)
		await node.ready

		NetworkIdentityServer.register_node(node)
		RollbackSynchronizationServer.register_state(node, "position")
		RollbackSynchronizationServer.register_state(node, "scale")
		
		var reference_snapshot := Snapshot.new(1)
		reference_snapshot.set_property(node, "position", Vector3.ZERO, true)
		reference_snapshot.set_property(node, "scale", Vector3.ONE, true)
		
		var current_snapshot := Snapshot.new(2)
		current_snapshot.set_property(node, "position", Vector3.ONE, true)
		reference_snapshot.set_property(node, "scale", Vector3.ONE * 2., true)
		
		var diff_snapshot := Snapshot.make_patch(reference_snapshot, current_snapshot)
		
		var serialized := RollbackSynchronizationServer._serialize_diff_state_of(1, diff_snapshot, reference_snapshot.tick)
		var buffer := StreamPeerBuffer.new(); buffer.data_array = serialized
		var deserialized := RollbackSynchronizationServer._deserialize_diff_state_of(1, buffer)
		
		expect_equal(deserialized.reference_tick, reference_snapshot.tick)
		expect_equal(deserialized.snapshot, diff_snapshot)
	)
