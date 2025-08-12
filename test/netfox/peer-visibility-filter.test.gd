extends VestTest

func get_suite_name():
	return "PeerVisibilityFilter"

func suite():
	var peers: Array[int] = [1, 2, 3, 4]

	test("should return all peers on default visibility", func():
		var filter := _PeerVisibilityFilter.new()
		filter.default_visibility = true
		filter.update_visibility(peers)

		assert_that(filter.get_visible_peers()).is_equal_to(peers)
	)

	test("should return no peers on default invisibility", func():
		var filter := _PeerVisibilityFilter.new()
		filter.default_visibility = false
		filter.update_visibility(peers)

		assert_that(filter.get_visible_peers()).is_empty()
	)

	test("should return force-visible peers on default invisibility", func():
		var filter := _PeerVisibilityFilter.new()
		filter.default_visibility = false
		filter.set_visibility_for(2, true)
		filter.update_visibility(peers)

		expect(filter.get_visibility_for(2), "Peer#2 should be visible!")
		expect_not(filter.get_visibility_for(1), "Peer#1 should not be visible!")
		assert_that(filter.get_visible_peers()).is_equal_to([2])
	)

	test("should return force-invisible peers on default visibility", func(): 
		var filter := _PeerVisibilityFilter.new()
		filter.default_visibility = true
		filter.set_visibility_for(2, false)
		filter.update_visibility(peers)

		expect_not(filter.get_visibility_for(2), "Peer#2 should not be visible!")
		expect(filter.get_visibility_for(1), "Peer#1 should be visible!")
		assert_that(filter.get_visible_peers()).is_equal_to([1, 3, 4])
	)

	# TODO: Filter tests

