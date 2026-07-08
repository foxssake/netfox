extends VestTest

func get_suite_name() -> String:
	return "NetworkSynchronizationServer"

var servers: TestingServers

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	servers = await TestingServers.create()

	servers.synchronization_server()._rb_enable_input_broadcast = true # Force input broadcast

func after_case(__):
	servers.queue_free()

func suite() -> void:
	define("synchronize_input()", func():
		test("should submit owned", func():
			var owned_node := await get_node()
			var other_node := await get_node()

			other_node.set_multiplayer_authority(2)

			servers.history_server().register_rollback_input(owned_node, "position")
			servers.history_server().register_rollback_input(other_node, "position")

			servers.synchronization_server().register_rollback_input(owned_node, "position")
			servers.synchronization_server().register_rollback_input(other_node, "position")

			servers.history_server()._record_rollback_input(0)
			servers.synchronization_server()._synchronize_input(0)

			skip() # Somehow setup a live client-server connection
		)
	)

	define("synchronize_state()", func():
		test("should submit owned", func():
			skip()
		)

		test("Includes newly authoritative subjects missing from the baseline", func() -> void:
			var host: RefCounted = RefCounted.new()
			var remote_player: RefCounted = RefCounted.new()
			var position: NodePath = NodePath("position")
			var reference: _Snapshot = _Snapshot.new(100)
			reference.set_property(host, position, Vector3.ZERO)
			reference.set_auth(host, true)

			var resimulated: _Snapshot = _Snapshot.new(100)
			resimulated.set_property(host, position, Vector3(1, 0, 0))
			resimulated.set_auth(host, true)
			resimulated.set_property(remote_player, position, Vector3(2, 0, 0))
			resimulated.set_auth(remote_player, true)

			var diff: _Snapshot = _Snapshot.make_patch(reference, resimulated)

			expect_true(diff.has_property(remote_player, position))
			expect_equal(diff.get_property(remote_player, position), Vector3(2, 0, 0))
		)
	)

	define("_make_peer_snapshot()", func():
		test("should include only visible owned auth state for target peer", func():
			var visible_node := await get_node("visible")
			var hidden_node := await get_node("hidden")
			var remote_node := await get_node("remote")
			remote_node.set_multiplayer_authority(2)

			visible_node.position = Vector3.ONE
			hidden_node.position = Vector3.UP
			remote_node.position = Vector3.RIGHT

			servers.synchronization_server().register_rollback_state(visible_node, ^"position")
			servers.synchronization_server().register_rollback_state(hidden_node, ^"position")
			servers.synchronization_server().register_rollback_state(remote_node, ^"position")

			var filter := PeerVisibilityFilter.new()
			filter.default_visibility = false
			filter.set_visibility_for(2, true)
			filter.update_visibility(PackedInt32Array([2, 3]))
			servers.synchronization_server().register_visibility_filter(visible_node, filter)

			var hidden_filter := PeerVisibilityFilter.new()
			hidden_filter.default_visibility = false
			hidden_filter.update_visibility(PackedInt32Array([2, 3]))
			servers.synchronization_server().register_visibility_filter(hidden_node, hidden_filter)

			var snapshot := _Snapshot.of(5, [
				[visible_node, ^"position", visible_node.position],
				[hidden_node, ^"position", hidden_node.position],
				[remote_node, ^"position", remote_node.position]
			], [visible_node, hidden_node, remote_node])

			var peer_snapshot := servers.synchronization_server()._make_peer_snapshot(
				snapshot,
				2,
				servers.synchronization_server()._rb_owned_state_properties
			)

			expect(peer_snapshot.has_property(visible_node, ^"position"))
			expect_equal(peer_snapshot.get_property(visible_node, ^"position"), Vector3.ONE)
			expect(peer_snapshot.is_auth(visible_node))
			expect_not(peer_snapshot.has_subject(hidden_node))
			expect_not(peer_snapshot.has_subject(remote_node))

			visible_node.queue_free()
			hidden_node.queue_free()
			remote_node.queue_free()
		)
	)

	define("rollback sent state history", func():
		test("should remember rollback state separately per peer", func():
			var node := await get_node("subject")
			var snapshot_tick_5 := _Snapshot.of(5, [
				[node, ^"position", Vector3.ONE]
			], [node])
			var snapshot_tick_8 := _Snapshot.of(8, [
				[node, ^"position", Vector3.UP]
			], [node])

			servers.synchronization_server()._remember_sent_rollback_state(2, snapshot_tick_5)
			servers.synchronization_server()._remember_sent_rollback_state(3, snapshot_tick_8)

			var peer_2_latest := servers.synchronization_server()._get_last_sent_rollback_state(2, 8)
			var peer_3_latest := servers.synchronization_server()._get_last_sent_rollback_state(3, 8)

			expect_not_null(peer_2_latest)
			expect_not_null(peer_3_latest)
			expect_equal(peer_2_latest.tick, 5)
			expect_equal(peer_2_latest.get_property(node, ^"position"), Vector3.ONE)
			expect_equal(peer_3_latest.tick, 8)
			expect_equal(peer_3_latest.get_property(node, ^"position"), Vector3.UP)
			expect_null(servers.synchronization_server()._get_last_sent_rollback_state(4, 8))

			node.queue_free()
		)

		test("should duplicate remembered rollback state", func():
			var node := await get_node("subject")
			var snapshot := _Snapshot.of(5, [
				[node, ^"position", Vector3.ONE]
			], [node])

			servers.synchronization_server()._remember_sent_rollback_state(2, snapshot)
			snapshot.set_property(node, ^"position", Vector3.ZERO)

			var remembered := servers.synchronization_server()._get_last_sent_rollback_state(2, 5)
			expect_not_null(remembered)
			expect_equal(remembered.get_property(node, ^"position"), Vector3.ONE)

			node.queue_free()
		)
	)

	define("synchronize_sync_state()", func():
		test("should submit owned", func():
			skip()
		)
	)

func get_node(name: String = "") -> Node3D:
	var node := Node3D.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	await node.ready
	if name: node.name = name

	return node
