extends VestTest

func get_suite_name() -> String:
	return "PropertyConfig"

const LOCAL_PEER := 1
const REMOTE_PEER := 2

func suite():
	var local_node := SnapshotFixtures.state_node()
	var remote_node := SnapshotFixtures.state_node()
	remote_node.set_multiplayer_authority(REMOTE_PEER)

	test("should get locally owned properties", func():
		var properties := SnapshotFixtures.state_propery_entries(local_node)
		var config := _PropertyConfig.new()
		config.set_properties(properties)
		config.local_peer_id = LOCAL_PEER

		expect_equal(config.get_owned_properties(), properties)
		expect_equal(config.get_properties_owned_by(LOCAL_PEER), properties)
		expect_empty(config.get_properties_owned_by(REMOTE_PEER))
	)

	test("should get remote owned properties", func():
		var properties := SnapshotFixtures.state_propery_entries(remote_node)
		var config := _PropertyConfig.new()
		config.set_properties(properties)
		config.local_peer_id = REMOTE_PEER

		expect_equal(config.get_properties_owned_by(REMOTE_PEER), properties)
		expect_empty(config.get_properties_owned_by(LOCAL_PEER))
	)

	test("should get remote owned properties after ownership change", func():
		var properties := SnapshotFixtures.state_properties()
		var cache := PropertyCache.new(remote_node)
		var config := _PropertyConfig.new()
		config.set_properties_from_paths(SnapshotFixtures.state_properties(), cache)
		config.local_peer_id = LOCAL_PEER

		expect_empty(config.get_owned_properties())

		# Update ownership
		remote_node.set_multiplayer_authority(1)
		config.set_properties_from_paths(SnapshotFixtures.state_properties(), cache)

		# Convert to a list of property paths for easier comparison
		var owned_properties := config.get_owned_properties()\
			.map(func(it): return str(it))
		expect_equal(owned_properties, properties)
	)

	on_finish.connect(func():
		local_node.queue_free()
		remote_node.queue_free()
	)
