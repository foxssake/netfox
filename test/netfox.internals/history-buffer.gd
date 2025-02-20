extends VestTest

func get_suite_name() -> String:
	return "HistoryBuffer"

func test_get_closest_tick_should_return_negative_on_empty():
	# Given
	var history_buffer := _HistoryBuffer.new()

	# When + then
	expect_equal(history_buffer.get_closest_tick(16), -1)

func test_get_closest_tick_should_return_earliest():
	# Given
	var history_buffer := _HistoryBuffer.new()
	history_buffer.set_snapshot(2, {})
	history_buffer.set_snapshot(4, {})
	history_buffer.set_snapshot(6, {})

	# When + then
	expect_equal(history_buffer.get_closest_tick(0), 2)

func test_get_closest_tick_should_return_latest():
	# Given
	var history_buffer := _HistoryBuffer.new()
	history_buffer.set_snapshot(2, {})
	history_buffer.set_snapshot(4, {})
	history_buffer.set_snapshot(6, {})

	# When + then
	expect_equal(history_buffer.get_closest_tick(8), 6)

func test_get_closest_tick_should_return_exact():
	# Given
	var history_buffer := _HistoryBuffer.new()
	history_buffer.set_snapshot(2, {})
	history_buffer.set_snapshot(4, {})
	history_buffer.set_snapshot(6, {})

	# When + then
	expect_equal(history_buffer.get_closest_tick(4), 4)

func test_get_closest_tick_should_return_previous():
	# Given
	var history_buffer := _HistoryBuffer.new()
	history_buffer.set_snapshot(2, {})
	history_buffer.set_snapshot(4, {})
	history_buffer.set_snapshot(6, {})

	# When + then
	expect_equal(history_buffer.get_closest_tick(5), 4)
