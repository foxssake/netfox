extends VestTest

func get_suite_name() -> String:
	return "NetworkTimeSynchronizerStalls"

var synchronizer: _NetworkTimeSynchronizer

func before_case(__):
	synchronizer = _NetworkTimeSynchronizer.new()

func after_case(__):
	synchronizer.queue_free()

func suite() -> void:
	test("should reject samples spanning longer than the stall threshold", func():
		var sample := NetworkClockSample.new()
		sample.ping_sent = 10.
		sample.pong_received = 10. + NetworkTime.stall_threshold + 0.1

		expect_not(synchronizer._is_sample_usable(sample))
	)

	test("should keep samples below the stall threshold", func():
		var sample := NetworkClockSample.new()
		sample.ping_sent = 10.
		sample.pong_received = 10. + NetworkTime.stall_threshold - 0.1

		expect(synchronizer._is_sample_usable(sample))
	)
