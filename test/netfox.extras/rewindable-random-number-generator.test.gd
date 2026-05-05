extends VestTest

const SOME_SEED = 3079
const OTHER_SEED = 9875

func get_suite_name():
	return "RewindableRandomNumberGenerator"

func suite():
	test("should generate the same numbers for the same rollback tick in different loop", func():
		NetworkMocks.in_rollback(func():
			var rng := RewindableRandomNumberGenerator.new(SOME_SEED)

			NetworkMocks.set_tick(2, 4)
			var first_batch := range(4).map(func(__): return rng.randi_range(0, 10))

			NetworkMocks.set_tick(3, 4)
			var second_batch := range(4).map(func(__): return rng.randi_range(0, 10))

			Vest.message("First batch: %s" % [first_batch])
			Vest.message("Second batch: %s" % [second_batch])
			expect_equal(first_batch, second_batch)
		)
	)

	test("should generate different numbers for different ticks", func():
		NetworkMocks.in_rollback(func():
			var rng := RewindableRandomNumberGenerator.new(SOME_SEED)

			NetworkMocks.set_tick(2, 4)
			var first_batch := range(4).map(func(__): return rng.randi_range(0, 10))

			NetworkMocks.set_tick(2, 2)
			var second_batch := range(4).map(func(__): return rng.randi_range(0, 10))

			Vest.message("First batch: %s" % [first_batch])
			Vest.message("Second batch: %s" % [second_batch])
			expect_not_equal(first_batch, second_batch)
		)
	)

	test("different seeds should generate different numbers", func():
		NetworkMocks.in_rollback(func():
			NetworkMocks.set_tick(0, 0)

			var first_rng := RewindableRandomNumberGenerator.new(SOME_SEED)
			var second_rng := RewindableRandomNumberGenerator.new(OTHER_SEED)

			var first_batch := range(4).map(func(__): return first_rng.randi_range(0, 10))
			var second_batch := range(4).map(func(__): return second_rng.randi_range(0, 10))

			Vest.message("First batch: %s" % [first_batch])
			Vest.message("Second batch: %s" % [second_batch])
			expect_not_equal(first_batch, second_batch)
		)
	)

	test("randf_range() should not need warmup", func():
		var rrng := RewindableRandomNumberGenerator.new(SOME_SEED)

		var batch := range(4).map(func(__): return rrng.randf_range(-1., 1.))

		Vest.message("Batch: %s" % [batch])
		expect_not_equal(batch[0], -1., "RRNG shouldn't start at lower bound!")
		expect_not_equal(batch[0], +1., "RRNG shouldn't start at upper bound!")
	)
