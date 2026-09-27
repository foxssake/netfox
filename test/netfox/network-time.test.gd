extends VestTest

func get_suite_name() -> String:
	return "NetworkTime"

var network_time: _NetworkTime

func before_case(__):
	network_time = _NetworkTime.new()

func after_case(__):
	network_time.queue_free()

func suite() -> void:
	define("_loop()", func():
		test("should re-anchor whole clock after stall", func():
			# Given
			var reference_time := NetworkTimeSynchronizer.get_time()
			network_time._clock.set_time(reference_time - 10.)
			network_time._last_process_time = reference_time - 10.
			network_time._next_tick_time = reference_time - 10.
			network_time._was_paused = true

			# When
			network_time._loop()

			# Then
			var clock_time := network_time._clock.get_time()
			expect(absf(NetworkTimeSynchronizer.get_time() - clock_time) < 1., "Clock was left behind!")
			expect_equal(network_time._next_tick_time, clock_time)
			expect_equal(network_time.tick, network_time.seconds_to_ticks(clock_time))
		)
	)
