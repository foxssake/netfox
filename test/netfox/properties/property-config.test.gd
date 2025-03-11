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

	on_finish.connect(func():
		local_node.queue_free()
		remote_node.queue_free()
	)
