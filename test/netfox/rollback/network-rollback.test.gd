extends VestTest

func get_suite_name() -> String:
	return "NetworkRollback"

var network_rollback: _NetworkRollback
var mutated_node: Node

func before_case(__):
	network_rollback = _NetworkRollback.new()
	mutated_node = Node.new()

func after_case(__):
	NetworkMocks.set_tick(0, 0)
	network_rollback.queue_free()
	mutated_node.queue_free()

func suite() -> void:
	define("mutate()", func():
		test("should be mutated after", func():
			# Given
			network_rollback.mutate(mutated_node, 8)

			# When + Then
			expect(network_rollback.is_mutated(mutated_node, 10))
			expect_not(network_rollback.is_just_mutated(mutated_node, 10))
		)

		test("should just be mutated", func():
			# Given
			network_rollback.mutate(mutated_node, 8)

			# When + Then
			expect(network_rollback.is_mutated(mutated_node, 8))
			expect(network_rollback.is_just_mutated(mutated_node, 8))
		)

		test("should not be mutated after", func():
			# Given
			network_rollback.mutate(mutated_node, 8)

			# When + Then
			expect_not(network_rollback.is_mutated(mutated_node, 4))
			expect_not(network_rollback.is_just_mutated(mutated_node, 4))
		)

		test("unknown should not be mutated", func():
			# Given nothing

			# Then
			expect_not(network_rollback.is_mutated(mutated_node, 8))
			expect_not(network_rollback.is_just_mutated(mutated_node, 8))
		)
	)

	define("reset()", func():
		test("should start over from tick 0", func():
			# Given
			network_rollback._tick = 500
			network_rollback._earliest_input = 498
			network_rollback._earliest_state = 499
			network_rollback.mutate(mutated_node, 500)

			# When
			network_rollback.reset()

			# Then
			expect_equal(network_rollback.tick, 0)
			expect_not(network_rollback.is_mutated(mutated_node, 500))
			expect_equal(network_rollback._earliest_input, -1)
			expect_equal(network_rollback._earliest_state, -1)
		)
	)

	define("_handle_tick_jump()", func():
		test("should advance the earliest valid history tick", func():
			# Given
			network_rollback._history_floor = 8

			# When
			network_rollback._handle_tick_jump(120)

			# Then
			expect_equal(network_rollback._history_floor, 120)
		)

		test("should never move the history floor backwards", func():
			# Given
			network_rollback._history_floor = 120

			# When
			network_rollback._handle_tick_jump(80)

			# Then
			expect_equal(network_rollback._history_floor, 120)
		)

		test("reset should clear the history floor", func():
			# Given
			network_rollback._history_floor = 120

			# When
			network_rollback.reset()

			# Then
			expect_equal(network_rollback._history_floor, 0)
		)

		test("should clamp a rollback range to the first tick after a gap", func():
			# Given
			NetworkMocks.set_network_tick(120)
			network_rollback._handle_tick_jump(120)
			network_rollback.before_loop.connect(func():
				network_rollback.notify_resimulation_start(1)
			)

			# When
			network_rollback._rollback()

			# Then
			expect_equal(network_rollback._rollback_from, 120)
			expect_equal(network_rollback._rollback_to, 120)
		)
	)
