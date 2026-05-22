extends VestTest

func get_suite_name() -> String:
	return "InterpolationServer"

var interpolation_server: _InterpolationServer
var test_node: Node3D
var group_id: int

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	interpolation_server = _InterpolationServer.new()
	test_node = Node3D.new()
	test_node.name = "TestNode"
	group_id = 12345

	Vest.get_tree().root.add_child.call_deferred(interpolation_server)
	Vest.get_tree().root.add_child.call_deferred(test_node)

	await interpolation_server.ready
	await test_node.ready

func after_case(__):
	interpolation_server.queue_free()
	test_node.queue_free()

func suite() -> void:
	define("register_interpolation_group()", func():
		test("should register group", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]

			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			expect(interpolation_server._groups.has(group_id), "Group should be registered")
			var group = interpolation_server._groups[group_id]
			expect_equal(group.root, test_node)
			expect_equal(group.properties, properties)
			expect(group.enabled)
			expect(group.enable_recording)
		)

		test("should cache interpolators on registration", func():
			test_node.position = Vector3(1, 2, 3)
			var properties := [":position"]

			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			var group = interpolation_server._groups[group_id]
			expect(group.interpolators.has(":position"), "Should have cached interpolator for position")
			expect(group.interpolators[":position"] is Callable, "Interpolator should be a Callable")
		)

		test("should re-register existing group", func():
			var properties1 := [":position"]
			var properties2 := [":position", ":rotation"]

			interpolation_server.register_interpolation_group(group_id, test_node, properties1, true, true)
			interpolation_server.register_interpolation_group(group_id, test_node, properties2, false, false)

			var group = interpolation_server._groups[group_id]
			expect_equal(group.properties, properties2, "Should update properties")
			expect_not(group.enabled, "Should update enabled flag")
			expect_not(group.enable_recording, "Should update recording flag")
		)
	)

	define("deregister_interpolation_group()", func():
		test("should remove registered group", func():
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			expect(interpolation_server._groups.has(group_id), "Group should exist")

			interpolation_server.deregister_interpolation_group(group_id)

			expect_not(interpolation_server._groups.has(group_id), "Group should be removed")
		)

		test("should handle unknown group gracefully", func():
			interpolation_server.deregister_interpolation_group(99999)
		)
	)

	define("can_interpolate()", func():
		test("should return false for unregistered group", func():
			expect_not(interpolation_server.can_interpolate(99999))
		)

		test("should return true when enabled with properties", func():
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			expect(interpolation_server.can_interpolate(group_id))
		)

		test("should return false when disabled", func():
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, false, true)

			expect_not(interpolation_server.can_interpolate(group_id))
		)

		test("should return false with empty properties", func():
			var properties: Array[String] = []
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			expect_not(interpolation_server.can_interpolate(group_id))
		)

		test("should return false when teleporting", func():
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			interpolation_server.teleport(group_id)

			expect_not(interpolation_server.can_interpolate(group_id))
		)
	)

	define("push_state()", func():
		test("should rotate states", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			interpolation_server.push_state(group_id)
			var group = interpolation_server._groups[group_id]
			var first_to_state = group.state_to

			test_node.position = Vector3(10, 0, 0)
			interpolation_server.push_state(group_id)

			expect_equal(group.state_from, first_to_state, "state_from should be previous state_to")
			expect(group.state_to.has(":position"), "New state_to should have position")
			expect_equal(group.state_to.get_value(":position"), Vector3(10, 0, 0))
		)

		test("should handle unregistered group gracefully", func():
			interpolation_server.push_state(99999)
		)
	)

	define("teleport()", func():
		test("should set both states to current", func():
			test_node.position = Vector3(5, 5, 5)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			interpolation_server.teleport(group_id)

			var group = interpolation_server._groups[group_id]
			expect(group.is_teleporting, "Should be in teleporting state")
			expect(group.state_from.has(":position"), "state_from should have position")
			expect(group.state_to.has(":position"), "state_to should have position")
			expect(group.state_from.equals(group.state_to), "Both states should be equal")
		)

		test("should not double-teleport", func():
			test_node.position = Vector3(5, 5, 5)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			interpolation_server.teleport(group_id)
			var group = interpolation_server._groups[group_id]
			var first_state = group.state_from

			test_node.position = Vector3(10, 10, 10)
			interpolation_server.teleport(group_id)

			expect_equal(group.state_from, first_state, "State should not change on double teleport")
		)

		test("should handle unregistered group gracefully", func():
			interpolation_server.teleport(99999)
		)
	)

	define("interpolate()", func():
		test("should interpolate between states", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			test_node.position = Vector3(0, 0, 0)
			interpolation_server.push_state(group_id)
			test_node.position = Vector3(10, 0, 0)
			interpolation_server.push_state(group_id)

			interpolation_server.interpolate(group_id, 0.5)

			expect_equal(test_node.position, Vector3(5, 0, 0))
		)

		test("should handle multiple properties", func():
			test_node.position = Vector3(0, 0, 0)
			test_node.rotation = Vector3(0, 0, 0)
			var properties := [":position", ":rotation"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			test_node.position = Vector3(0, 0, 0)
			test_node.rotation = Vector3(0, 0, 0)
			interpolation_server.push_state(group_id)

			test_node.position = Vector3(10, 10, 10)
			test_node.rotation = Vector3(PI, 0, 0)
			interpolation_server.push_state(group_id)
			interpolation_server.interpolate(group_id, 0.25)

			expect_equal(test_node.position, Vector3(2.5, 2.5, 2.5))
			expect(abs(test_node.rotation.x - PI * 0.25) < 0.01, "Rotation should be approximately PI * 0.25")
		)

		test("should not interpolate when disabled", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, false, true)

			test_node.position = Vector3(0, 0, 0)
			interpolation_server.push_state(group_id)
			test_node.position = Vector3(10, 0, 0)
			interpolation_server.push_state(group_id)
			interpolation_server.interpolate(group_id, 0.5)

			expect_equal(test_node.position, Vector3(10, 0, 0))
		)

		test("should handle unregistered group gracefully", func():
			interpolation_server.interpolate(99999, 0.5)
		)
	)

	define("tick loop integration", func():
		test("_before_tick_loop should reset teleprt flag", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			interpolation_server.teleport(group_id)
			var group = interpolation_server._groups[group_id]
			expect(group.is_teleporting, "Should be teleporting")

			interpolation_server._before_tick_loop()

			expect_not(group.is_teleporting, "Should reset teleport flag")
		)

		test("_after_tick_loop should auto-push with recording enabled", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			test_node.position = Vector3(0, 0, 0)
			interpolation_server.push_state(group_id)

			test_node.position = Vector3(10, 0, 0)
			interpolation_server._after_tick_loop()

			var group = interpolation_server._groups[group_id]
			expect(group.state_to.has(":position"))
			expect_equal(group.state_to.get_value(":position"), Vector3(10, 0, 0))
		)

		test("_after_tick_loop should not push when recording disabled", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, false)

			test_node.position = Vector3(0, 0, 0)
			interpolation_server.push_state(group_id)
			var group = interpolation_server._groups[group_id]
			var original_to = group.state_to

			expect_equal(group.state_to, original_to)
		)

		test("_after_tick_loop should not push when teleporting", func():
			test_node.position = Vector3(0, 0, 0)
			var properties := [":position"]
			interpolation_server.register_interpolation_group(group_id, test_node, properties, true, true)

			interpolation_server.teleport(group_id)
			var group = interpolation_server._groups[group_id]
			var teleport_state = group.state_to
			test_node.position = Vector3(10, 0, 0)
			interpolation_server._after_tick_loop()

			expect_equal(group.state_to, teleport_state)
		)
	)
