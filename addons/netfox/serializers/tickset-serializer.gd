extends Object
class_name _TicksetSerializer

static func serialize(earliest_tick: int, latest_tick: int, active_ticks: _Set) -> PackedByteArray:
	var bytes := PackedByteArray()
	var tickset_duration = latest_tick - earliest_tick

	assert(latest_tick >= earliest_tick, "Tickset ends before it starts!")
	assert(tickset_duration <= 255, "Tickset covers more than supported 255 ticks!")

	bytes.resize(5 + active_ticks.size())
	bytes.encode_u32(0, earliest_tick)
	bytes.encode_u8(4, tickset_duration)

	var tick_idx = 0
	for tick in active_ticks:
		assert(tick <= latest_tick, "Trying to serialize ticks beyond latest !")
		bytes.encode_u8(5 + tick_idx, tick - earliest_tick)
		tick_idx += 1

	return bytes

static func deserialize(bytes: PackedByteArray) -> Array:
	var earliest_tick := -1
	var tickset_duration := 0
	var latest_tick := -1
	var active_ticks := _Set.new()

	earliest_tick = bytes.decode_u32(0)
	tickset_duration = bytes.decode_u8(4)
	latest_tick = earliest_tick + tickset_duration

	for byte_idx in range(5, bytes.size()):
		var tick = earliest_tick + bytes.decode_u8(byte_idx)
		active_ticks.add(tick)

	return [earliest_tick, latest_tick, active_ticks]
