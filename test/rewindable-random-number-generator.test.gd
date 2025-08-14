extends VestTest

func get_suite_name():
	return "RewindableRandomNumberGenerator"

func before_case(__) -> void:
	NetworkRollback._is_rollback = true # Mock rollback

func after_case(__) -> void:
	NetworkRollback._is_rollback = false # Reset

func suite():
	test("should generate the same numbers for the same rollback tick", func():
		var rng := RewindableRandomNumberGenerator.new(0)

		NetworkTime._tick = 2
		NetworkRollback._tick = 4
		var first_batch := range(4).map(func(__): return rng.randi_range(0, 10))
		
		NetworkTime._tick = 3
		var second_batch := range(4).map(func(__): return rng.randi_range(0, 10))

		expect_equal(first_batch, second_batch)
	)

	test("should generate different numbers for different ticks", func():
		var rng := RewindableRandomNumberGenerator.new(0)

		NetworkTime._tick = 2
		NetworkRollback._tick = 4
		var first_batch := range(4).map(func(__): return rng.randi_range(0, 10))
		
		NetworkTime._tick = 3
		NetworkRollback._tick = 2
		var second_batch := range(4).map(func(__): return rng.randi_range(0, 10))

		expect_not_equal(first_batch, second_batch)
	)

	test("different seeds should generate different numbers", func():
		var first_rng := RewindableRandomNumberGenerator.new(1)
		var second_rng := RewindableRandomNumberGenerator.new(2)

		var first_batch := range(4).map(func(__): return first_rng.randi_range(0, 10))
		var second_batch := range(4).map(func(__): return second_rng.randi_range(0, 10))

		expect_not_equal(first_batch, second_batch)
	)
