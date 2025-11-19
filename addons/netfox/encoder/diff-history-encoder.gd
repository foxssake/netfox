extends RefCounted
class_name _DiffHistoryEncoder

var _history: _PropertyHistoryBuffer
var _property_cache: PropertyCache

var _full_snapshot := {}
var _encoded_snapshot := {}

var _property_indexes := _BiMap.new()

var _version := 0
var _has_received := false

static var _logger := NetfoxLogger._for_netfox("DiffHistoryEncoder")

func _init(p_history: _PropertyHistoryBuffer, p_property_cache: PropertyCache):
	_history = p_history
	_property_cache = p_property_cache

func add_properties(properties: Array[PropertyEntry]) -> void:
	var has_new_properties := false

	for property_entry in properties:
		var is_new := _ensure_property_idx(property_entry.to_string())
		has_new_properties = has_new_properties or is_new

	# If we added any new properties, increment version
	if has_new_properties:
		_version = (_version + 1) % 256

func encode(tick: int, reference_tick: int, properties: Array[PropertyEntry]) -> PackedByteArray:
	assert(properties.size() <= 255, "Property indices may not fit into bytes!")

	var snapshot := _history.get_snapshot(tick)
	var property_strings := properties.map(func(it): return it.to_string())

	var reference_snapshot := _history.get_history(reference_tick)
	var diff_snapshot := reference_snapshot.make_patch(snapshot)

	_full_snapshot = snapshot.as_dictionary()
	_encoded_snapshot = diff_snapshot.as_dictionary()

	if diff_snapshot.is_empty():
		return PackedByteArray()

	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(_version)

	for property in diff_snapshot.properties():
		var property_idx := _property_indexes.get_by_value(property) as int
		var property_value = diff_snapshot.get_value(property)

		buffer.put_u8(property_idx)
		buffer.put_var(property_value)

	return buffer.data_array

func decode(data: PackedByteArray, properties: Array[PropertyEntry]) -> _PropertySnapshot:
	var result := _PropertySnapshot.new()

	if data.is_empty():
		return result

	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	var packet_version := buffer.get_u8()
	if packet_version != _version:
		if not _has_received:
			# This is the first time we receive data
			# Assume the version is OK
			_version = packet_version
		else:
			# Since we don't remove entries, only add, we can still parse what
			# we can
			_logger.warning("Property config version mismatch - own %d != received %d", [_version, packet_version])

	_has_received = true

	while buffer.get_available_bytes() > 0:
		var property_idx := buffer.get_u8()
		var property_value := buffer.get_var()
		if not _property_indexes.has_key(property_idx):
			_logger.warning("Received unknown property index %d, ignoring!", [property_idx])
			continue

		var property_entry := _property_indexes.get_by_key(property_idx)
		result.set_value(property_entry, property_value)

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
		_logger.warning("Reference tick %d missing for #%s applying %d", [reference_tick, sender, tick])

	var reference_snapshot := _history.get_snapshot(reference_tick)
	_history.set_snapshot(tick, reference_snapshot.merge(snapshot))
	return true

# TODO: Rework metrics so these are not needed
func get_encoded_snapshot() -> Dictionary:
	return _encoded_snapshot

func get_full_snapshot() -> Dictionary:
	return _full_snapshot

func _ensure_property_idx(property: String) -> bool:
	if _property_indexes.has_value(property):
		return false

	assert(_property_indexes.size() < 256, "Property index map is full, can't add new property!")
	var idx := hash(property) % 256
	while _property_indexes.has_key(idx):
		idx = hash(idx + 1) % 256
	_property_indexes.put(idx, property)

	return true
