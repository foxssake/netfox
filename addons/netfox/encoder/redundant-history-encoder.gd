extends RefCounted
class_name _RedundantHistoryEncoder

var redundancy: int = 4:
	get = get_redundancy,
	set = set_redundancy

var _history: _PropertyHistoryBuffer
var _properties: Array[PropertyEntry]
var _property_cache: PropertyCache

var _version := 0
var _has_received := false

var _logger := NetfoxLogger._for_netfox("RedundantHistoryEncoder")

func get_redundancy() -> int:
	return redundancy

func set_redundancy(p_redundancy: int):
	if p_redundancy <= 0:
		_logger.warning(
			"Attempting to set redundancy to %d, which would send no data!", [p_redundancy]
		)
		return

	redundancy = p_redundancy

func set_properties(properties: Array[PropertyEntry]) -> void:
	if _properties != properties:
		_version = (_version + 1) % 256
		_properties = properties.duplicate()

func encode(tick: int, properties: Array[PropertyEntry]) -> Array:
	if _history.is_empty():
		return []
	var data := []

	for i in range(mini(redundancy, _history.size())):
		var offset_tick := tick - i
		if offset_tick < _history.get_earliest_tick():
			break

		var snapshot := _history.get_snapshot(offset_tick)
		for property in properties:
			data.append(snapshot.get_value(property.to_string()))

	data.append(_version)
	return data

func decode(data: Array, properties: Array[PropertyEntry]) -> Array[_PropertySnapshot]:
	if data.is_empty() or properties.is_empty():
		return []
	
	var packet_version := data.pop_back() as int

	if packet_version != _version:
		if not _has_received:
			# First packet, assume version is OK
			_version = packet_version
		else:
			# Version mismatch, can't parse
			_logger.warning("Version mismatch! own: %d, received: %s", [_version, packet_version])
			return []
	
	var result: Array[_PropertySnapshot] = []
	var redundancy := data.size() / properties.size()
	result.assign(range(redundancy)
		.map(func(__): return _PropertySnapshot.new())
	)

	for i in range(data.size()):
		var offset_idx := i / properties.size()
		var prop_idx := i % properties.size()

		result[offset_idx].set_value(properties[prop_idx].to_string(), data[i])

	_has_received = true

	return result

# Returns earliest new tick as int, or -1 if no new ticks applied
func apply(tick: int, snapshots: Array[_PropertySnapshot], sender: int = 0) -> int:
	var earliest_new_tick = -1

	for i in range(snapshots.size()):
		var offset_tick := tick - i
		var snapshot := snapshots[i]

		if offset_tick < NetworkRollback.history_start:
			# Data too old
			_logger.warning(
				"Received data for %s, rejecting because older than %s frames",
				[offset_tick, NetworkRollback.history_limit]
			)
			continue

		if sender > 0:
			snapshot.sanitize(sender, _property_cache)
			if snapshot.is_empty():
				# No valid properties ( probably after sanitize )
				_logger.warning("Received invalid data from %d for tick %d", [sender, tick])
				continue

		var known_snapshot := _history.get_snapshot(offset_tick)
		if not known_snapshot.equals(snapshot):
			# Received a new snapshot, store and emit signal
			_history.set_snapshot(offset_tick, snapshot)
			earliest_new_tick = offset_tick

	return earliest_new_tick


func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache
