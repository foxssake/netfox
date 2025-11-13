extends VestTest

func get_suite_name():
	return "RewindableAction"

var rewindable_action: RewindableAction

func before_case(__) -> void:
	rewindable_action = RewindableAction.new()
	# TODO(vest): Some good way to add nodes to the tree
	await NetworkTime.get_tree().process_frame
	NetworkTime.get_tree().root.add_child(rewindable_action)

func after_case(__) -> void:
	rewindable_action.free()

func test_should_empty_queue_after_loop():
	# Run as client
	rewindable_action.set_multiplayer_authority(2)

	# Prepare changes
	var tickset := _Set.of([0])
	var data := _TicksetSerializer.serialize(0, 4, tickset)
	NetworkMocks.set_tick(4, 4)

	# Run first loop
	rewindable_action._submit_state(data)	# Server sends data
	NetworkMocks.run_network_tick_loop()
	expect(rewindable_action.has_confirmed(), "RewindableAction was not confirmed!")

	# Run second loop
	rewindable_action._submit_state(data)	# Server sends data again
	NetworkMocks.run_network_tick_loop()
	expect_not(rewindable_action.has_confirmed(), "RewindableAction was redundantly confirmed!")
