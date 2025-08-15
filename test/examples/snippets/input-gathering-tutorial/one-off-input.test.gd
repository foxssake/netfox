extends VestTest

const OneOffInput = preload("res://examples/snippets/input-gathering-tutorial/one-off-input.gd")

func get_suite_name():
	return "OneOffInput"

func suite():
	var action = "move_jump"
	var input := OneOffInput.new()

	# TODO(vest): Some good way to add nodes to the tree
	await NetworkTime.get_tree().process_frame
	NetworkTime.get_tree().root.add_child(input)

	test("should return false with no input", func():
		expect_false(input.is_jumping)
	)

	test("should return true for a single tick", func():
		# Activate input
		Input.action_press(action)
		# Process
		input._process(1. / 60.)
		# Deactive input
		Input.action_release(action)

		# Start tick loop
		NetworkMocks.in_network_tick_loop(func():
			# Single tick
			NetworkMocks.in_network_tick()

			# Check for result
			expect_true(input.is_jumping)
		)
	)

	test("should return true only on the first tick", func(): 
		# Activate input
		Input.action_press(action)
		# Process
		input._process(1. / 60.)
		# Deactive input
		Input.action_release(action)

		# Start tick loop
		NetworkMocks.in_network_tick_loop(func():
			# First tick
			NetworkMocks.in_network_tick()
			expect_true(input.is_jumping, "First tick should have input!")

			# Second tick
			NetworkMocks.in_network_tick()
			expect_false(input.is_jumping, "Second tick should not have input!")
		)
	)
