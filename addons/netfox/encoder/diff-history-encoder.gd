extends RefCounted
class_name _DiffHistoryEncoder

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

static var _logger := _NetfoxLogger.for_netfox("DiffHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func encode(tick: int, reference_tick: int, property_entries: Array[PropertyEntry]) -> PackedByteArray:
	assert(property_entries.size() <= 255, "Property indices may not fit into bytes!")

	var snapshot := _history.get_snapshot(tick)
	var property_strings := property_entries.map(func(it): return it.to_string())

	var reference_snapshot := _history.get_history(reference_tick)
	var diff_snapshot := reference_snapshot.make_patch(snapshot)

	var result := PackedByteArray()
	if diff_snapshot.is_empty():
		return result

	for property in diff_snapshot.properties():
		var property_idx := property_strings.find(property)
		if property_idx < 0:
			continue

		var property_value = diff_snapshot.get_value(property)
		var property_buffer := PackedByteArray()
		property_buffer.resize(1)
		property_buffer.encode_u8(0, property_idx)
		property_buffer.append_array(var_to_bytes(property_value))

		result.append_array(property_buffer)

	return result

func decode(data: PackedByteArray, property_entries: Array[PropertyEntry]) -> _PropertySnapshot:
	var result := _PropertySnapshot.new()

	if data.is_empty():
		return result

	var at := 0
	while at < data.size():
		var property_idx := data.decode_u8(at)
		var property_value := data.decode_var(at + 1)
		var property_size := data.decode_var_size(at + 1)

		var property_entry := property_entries[property_idx]

		result.set_value(property_entry.to_string(), property_value)

		at += property_size + 1

	return result

func apply(tick: int, snapshot: _PropertySnapshot, reference_tick: int, sender: int = -1) -> bool:
	if tick < NetworkRollback.history_start:
		# State too old!
		_logger.error(
			"Received diff snapshot for @%d, rejecting because older than %s frames",
			[tick, NetworkRollback.history_limit]
		)
		return false

	if snapshot.is_empty():
		return true

	if sender > 0:
		snapshot.sanitize(sender, _property_cache)
		if snapshot.is_empty():
			_logger.warning("Received invalid diff from #%s for @%s", [sender, tick])
			return false

	if not _history.has(reference_tick):
		# Reference tick missing, hope for the best
		_logger.warning("Reference tick %d missing for applying %d", [reference_tick, tick])

	var reference_snapshot := _history.get_snapshot(reference_tick)
	_history.set_snapshot(tick, reference_snapshot.merge(snapshot))
	return true
