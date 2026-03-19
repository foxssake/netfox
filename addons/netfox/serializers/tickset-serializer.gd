extends Object
class_name _TicksetSerializer

static func serialize(earliest_tick: int, latest_tick: int, active_ticks: _Set) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	var tickset_duration = latest_tick - earliest_tick

	assert(latest_tick >= earliest_tick, "Tickset ends before it starts!")
	assert(tickset_duration <= 255, "Tickset covers more than supported 255 ticks!")

	buffer.put_u32(earliest_tick)
	buffer.put_u8(tickset_duration)

	for tick in active_ticks:
		# Don't serialize before range
		if tick < earliest_tick: continue
		# Don't serialize past range
		if tick > latest_tick: break
		buffer.put_u8(tick - earliest_tick)

	return buffer.data_array

static func deserialize(bytes: PackedByteArray) -> Array:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes

	var earliest_tick := buffer.get_u32()
	var tickset_duration := buffer.get_u8()
	var latest_tick := earliest_tick + tickset_duration

	var active_ticks := _Set.new()

	while buffer.get_available_bytes() > 0:
		var tick = earliest_tick + buffer.get_u8()
		active_ticks.add(tick)

	return [earliest_tick, latest_tick, active_ticks]
