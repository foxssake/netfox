extends VestTest

func get_suite_name():
	return "RewindableRandomNumberGenerator"

func before_case(__) -> void:
	NetworkRollback._is_rollback = true # Mock rollback

func after_case(__) -> void:
	NetworkRollback._is_rollback = false # Reset

func suite():
	test("should generate the same numbers for the same rollback tick in different loop", func():
		NetworkMocks.in_rollback(func():
			var rng := RewindableRandomNumberGenerator.new(0)
			
			NetworkMocks.set_tick(2, 4)
			var first_batch := range(4).map(func(__): return rng.randi_range(0, 10))
		
			NetworkMocks.set_tick(3, 4)
			var second_batch := range(4).map(func(__): return rng.randi_range(0, 10))

			expect_equal(first_batch, second_batch)
		)
	)

	test("should generate different numbers for different ticks", func():
		NetworkMocks.in_rollback(func():
			var rng := RewindableRandomNumberGenerator.new(0)

			NetworkMocks.set_tick(2, 4)
			var first_batch := range(4).map(func(__): return rng.randi_range(0, 10))
			
			NetworkMocks.set_tick(2, 2)
			var second_batch := range(4).map(func(__): return rng.randi_range(0, 10))

			expect_not_equal(first_batch, second_batch)
		)
	)

	test("different seeds should generate different numbers", func():
		NetworkMocks.in_rollback(func():
			NetworkMocks.set_tick(0, 0)

			var first_rng := RewindableRandomNumberGenerator.new(1)
			var second_rng := RewindableRandomNumberGenerator.new(2)

			var first_batch := range(4).map(func(__): return first_rng.randi_range(0, 10))
			var second_batch := range(4).map(func(__): return second_rng.randi_range(0, 10))

			expect_not_equal(first_batch, second_batch)
		)
	)
