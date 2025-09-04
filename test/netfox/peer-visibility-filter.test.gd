extends VestTest

func get_suite_name():
	return "PeerVisibilityFilter"

func suite():
	var peers: Array[int] = [1, 2, 3, 4]

	define("Visibility override", func():
		test("should return all peers on default visibility", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = true
			filter.update_visibility(peers)

			assert_that(filter.get_visible_peers()).is_equal_to(peers)
			assert_that(filter.get_rpc_target_peers()).is_equal_to([0])
		)

		test("should return no peers on default invisibility", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = false
			filter.update_visibility(peers)

			assert_that(filter.get_visible_peers()).is_empty()
			assert_that(filter.get_rpc_target_peers()).is_empty()
		)

		test("should return force-visible peers on default invisibility", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = false
			filter.set_visibility_for(2, true)
			filter.update_visibility(peers)

			expect(filter.get_visibility_for(2), "Peer#2 should be visible!")
			expect_not(filter.get_visibility_for(1), "Peer#1 should not be visible!")
			assert_that(filter.get_visible_peers()).is_equal_to([2])
			assert_that(filter.get_rpc_target_peers()).is_equal_to([2])
		)

		test("should return force-invisible peers on default visibility", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = true
			filter.set_visibility_for(2, false)
			filter.update_visibility(peers)

			expect_not(filter.get_visibility_for(2), "Peer#2 should not be visible!")
			expect(filter.get_visibility_for(1), "Peer#1 should be visible!")
			assert_that(filter.get_visible_peers()).is_equal_to([1, 3, 4])
			assert_that(filter.get_rpc_target_peers()).is_equal_to([-2])
		)
		
		test("should return peers with multiple excludes", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = true
			filter.set_visibility_for(2, false)
			filter.set_visibility_for(4, false)
			filter.update_visibility(peers)

			expect_not(filter.get_visibility_for(2), "Peer#2 should not be visible!")
			expect(filter.get_visibility_for(1), "Peer#1 should be visible!")
			assert_that(filter.get_visible_peers()).is_equal_to([1, 3])
			assert_that(filter.get_rpc_target_peers()).is_equal_to([1, 3])
		)
	)

	define("Visibility filters", func():
		test("should pass through on true", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = true
			filter.add_visibility_filter(func(peer: int): return true)

			filter.update_visibility(peers)

			assert_that(filter.get_visible_peers()).is_equal_to(peers)
		)

		test("should exclude on false", func(): 
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = true
			filter.add_visibility_filter(func(peer: int): return false)

			filter.update_visibility(peers)

			assert_that(filter.get_visible_peers()).is_empty()
		)

		test("should exclude if any returns false", func():
			var filter := _PeerVisibilityFilter.new()
			filter.default_visibility = true
			filter.add_visibility_filter(func(peer: int): return true)
			filter.add_visibility_filter(func(peer: int): return false)

			filter.update_visibility(peers)

			assert_that(filter.get_visible_peers()).is_empty()
		)
	)

	test("filter should have precendence over override", func():
		var excluded_peer := 2
		var filter := _PeerVisibilityFilter.new()
		filter.default_visibility = false
		filter.set_visibility_for(excluded_peer, true)
		filter.add_visibility_filter(func(peer: int):
			if peer == excluded_peer: return false
			else: return true
		)

		filter.update_visibility(peers)
		assert_that(filter.get_visible_peers()).is_empty()
	)
