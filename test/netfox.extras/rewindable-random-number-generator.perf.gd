extends VestTest

func get_suite_name():
	return "RewindableRandomNumberGenerator performance tests"

func test_benchmark() -> void:
	var rng := RandomNumberGenerator.new()
	var rrng := RewindableRandomNumberGenerator.new(0)
	var sum := 0.0

	benchmark("Built-in RNG", func(__):
		sum += rng.randfn()
	)\
	.with_duration(1.0)\
	.with_batch_size(4096)\
	.run()

	NetworkMocks.in_rollback(func():
		NetworkMocks.set_tick(0, 0)

		benchmark("Rewindable RNG on the same tick", func(__):
			sum += rrng.randfn()
		)\
		.with_duration(1.0)\
		.with_batch_size(4096)\
		.run()

		benchmark("Rewindable RNG on the changing tick", func(__):
			NetworkRollback._tick += 1
			sum += rrng.randfn()
		)\
		.with_duration(1.0)\
		.with_batch_size(4096)\
		.run()
	)
