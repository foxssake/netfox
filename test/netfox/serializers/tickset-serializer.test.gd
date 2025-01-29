extends VestTest

func get_suite_name() -> String:
	return "TicksetSerializer"

func test_should_serialize_empty():
	# Given
	var earliest_tick = 15
	var latest_tick = 35
	var active_ticks = _Set.new()

	# When
	var bytes = _TicksetSerializer.serialize(earliest_tick, latest_tick, active_ticks)
	var deserialized = _TicksetSerializer.deserialize(bytes)

	# Then
	expect_equal(deserialized[0], earliest_tick)
	expect_equal(deserialized[1], latest_tick)
	expect_equal(deserialized[2], active_ticks)

func test_should_serialize_ticks():
	# Given
	var earliest_tick = 15
	var latest_tick = 35
	var active_ticks = _Set.of([15, 16, 20, 24])

	# When
	var bytes = _TicksetSerializer.serialize(earliest_tick, latest_tick, active_ticks)
	var deserialized = _TicksetSerializer.deserialize(bytes)

	# Then
	expect_equal(deserialized[0], earliest_tick)
	expect_equal(deserialized[1], latest_tick)
	expect_equal(deserialized[2], active_ticks)

func test_should_fail_on_earliest_after_latest():
	# Given
	var earliest_tick = 42
	var latest_tick = 12
	var active_ticks = _Set.new()

	# When
	var bytes = _TicksetSerializer.serialize(earliest_tick, latest_tick, active_ticks)

	expect(bytes.is_empty())
