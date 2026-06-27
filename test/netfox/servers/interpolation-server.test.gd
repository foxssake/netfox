extends VestTest

func get_suite_name() -> String:
	return "InterpolationServer"

var interpolation_server: _InterpolationServer
var test_node: Node3D

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	interpolation_server = _InterpolationServer.new()
	test_node = Node3D.new()
	test_node.name = "TestNode"

	Vest.get_tree().root.add_child.call_deferred(interpolation_server)
	Vest.get_tree().root.add_child.call_deferred(test_node)

	await interpolation_server.ready
	await test_node.ready

func after_case(__):
	interpolation_server.queue_free()
	test_node.queue_free()

func suite() -> void:
	define("register()", func():
		test("should register subject", func():
			test_node.position = Vector3(0, 0, 0)

			interpolation_server.register(test_node, ":position")
			interpolation_server.register(test_node, ":rotation")

			expect(interpolation_server.has_subject(test_node), "Subject should be registered")
			expect(interpolation_server.is_enabled(test_node), "Should be enabled by default")
			expect(interpolation_server.is_recording(test_node), "Should have recording enabled by default")
		)

		test("should do nothing on re-registering property", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.register(test_node, ":position")

			expect(interpolation_server.has_subject(test_node), "Subject should be registered")
		)
	)

	define("deregister()", func():
		test("should remove registered subject", func():
			interpolation_server.register(test_node, ":position")
			expect(interpolation_server.has_subject(test_node), "Subject should exist")

			interpolation_server.deregister(test_node)
			expect_not(interpolation_server.has_subject(test_node), "Subject should be removed")
			expect_not(interpolation_server.is_enabled(test_node))
			expect_not(interpolation_server.is_recording(test_node))
			expect_not(interpolation_server.can_interpolate(test_node))
		)

		test("should handle unknown subject gracefully", func():
			interpolation_server.deregister(test_node)
			expect_not(interpolation_server.has_subject(test_node))
		)
	)

	define("set_enabled()", func():
		test("should disable interpolation for subject", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.set_enabled(test_node, false)

			expect_not(interpolation_server.is_enabled(test_node))
			expect_not(interpolation_server.can_interpolate(test_node))
		)

		test("should re-enable interpolation for subject", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.set_enabled(test_node, false)
			interpolation_server.set_enabled(test_node, true)

			expect(interpolation_server.is_enabled(test_node))
			expect(interpolation_server.can_interpolate(test_node))
		)
	)

	define("set_recording()", func():
		test("should disable recording for subject", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.set_recording(test_node, false)

			expect_not(interpolation_server.is_recording(test_node))
			expect(interpolation_server.can_interpolate(test_node))
		)

		test("should re-enable recording for subject", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.set_recording(test_node, false)
			interpolation_server.set_recording(test_node, true)

			expect(interpolation_server.is_recording(test_node))
			expect(interpolation_server.can_interpolate(test_node))
		)
	)

	define("can_interpolate()", func():
		test("should return false for unregistered subject", func():
			expect_not(interpolation_server.can_interpolate(test_node))
		)

		test("should return true when enabled with properties", func():
			interpolation_server.register(test_node, ":position")

			expect(interpolation_server.can_interpolate(test_node))
		)

		test("should return true after re-enabling with properties", func():
			interpolation_server.register(test_node, ":position")

			interpolation_server.set_enabled(test_node, false)
			expect_not(interpolation_server.can_interpolate(test_node))

			interpolation_server.set_enabled(test_node, true)
			expect(interpolation_server.can_interpolate(test_node))
		)

		test("should return false when disabled", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.set_enabled(test_node, false)

			expect_not(interpolation_server.can_interpolate(test_node))
		)

		test("should return false when teleporting", func():
			interpolation_server.register(test_node, ":position")
			interpolation_server.teleport(test_node)

			expect_not(interpolation_server.can_interpolate(test_node))
		)
	)

	define("push_state()", func():
		test("should rotate states", func():
			test_node.position = Vector3(0, 0, 0)
			interpolation_server.register(test_node, ":position")

			interpolation_server.push_state(test_node)
			interpolation_server.interpolate_subject(test_node, 1.)
			var first_to_pos = test_node.position

			test_node.position = Vector3(10, 0, 0)
			interpolation_server.push_state(test_node)

			interpolation_server.interpolate_subject(test_node, 0.)
			expect_equal(test_node.position, first_to_pos, "state_from should be previous state_to")

			interpolation_server.interpolate_subject(test_node, 1.)
			expect_equal(test_node.position, Vector3(10, 0, 0))
		)

		test("should handle unregistered subject gracefully", func():
			interpolation_server.push_state(test_node)
			expect_not(interpolation_server.has_subject(test_node))
		)
	)

	define("interpolate_subject()", func():
		test("should interpolate between states", func():
			test_node.position = Vector3(0, 0, 0)
			interpolation_server.register(test_node, ":position")

			test_node.position = Vector3(0, 0, 0)
			interpolation_server.push_state(test_node)
			test_node.position = Vector3(10, 0, 0)
			interpolation_server.push_state(test_node)

			interpolation_server.interpolate_subject(test_node, 0.5)

			expect_equal(test_node.position, Vector3(5, 0, 0))
		)

		test("should handle multiple properties", func():
			test_node.position = Vector3(0, 0, 0)
			test_node.rotation = Vector3(0, 0, 0)
			interpolation_server.register(test_node, ":position")
			interpolation_server.register(test_node, ":rotation")

			test_node.position = Vector3(0, 0, 0)
			test_node.rotation = Vector3(0, 0, 0)
			interpolation_server.push_state(test_node)

			test_node.position = Vector3(10, 10, 10)
			test_node.rotation = Vector3(PI, 0, 0)
			interpolation_server.push_state(test_node)
			interpolation_server.interpolate_subject(test_node, 0.25)

			expect_equal(test_node.position, Vector3(2.5, 2.5, 2.5))
			expect(abs(test_node.rotation.x - PI * 0.25) < 0.01, "Rotation should be approximately PI * 0.25")
		)

		test("should not interpolate when disabled", func():
			test_node.position = Vector3(0, 0, 0)
			interpolation_server.register(test_node, ":position")
			interpolation_server.set_enabled(test_node, false)

			test_node.position = Vector3(0, 0, 0)
			interpolation_server.push_state(test_node)
			test_node.position = Vector3(10, 0, 0)
			interpolation_server.push_state(test_node)
			interpolation_server.interpolate_subject(test_node, 0.5)

			expect_equal(test_node.position, Vector3(10, 0, 0))
		)

		test("should handle unregistered subject gracefully", func():
			var pos_before := test_node.position
			interpolation_server.interpolate_subject(test_node, 0.5)
			expect_equal(test_node.position, pos_before)
		)
	)

	define("tick loop integration", func():
		test("_clear_teleports should reset teleport flag", func():
			test_node.position = Vector3(0, 0, 0)
			interpolation_server.register(test_node, ":position")

			interpolation_server.teleport(test_node)
			expect(interpolation_server._teleported.has(test_node), "Should be teleporting")

			interpolation_server._clear_teleports()

			expect_not(interpolation_server._teleported.has(test_node), "Should reset teleport flag")
		)
	)
