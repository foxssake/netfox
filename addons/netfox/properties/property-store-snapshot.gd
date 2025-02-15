class_name _PropertyStoreSnapshot extends RefCounted

# Maps property paths to their values
# Dictionary[String, Variant]
var _snapshot: Dictionary = {}

static var _logger := _NetfoxLogger.for_netfox("PropertyStoreSnapshot")

func as_dictionary() -> Dictionary:
	return _snapshot.duplicate()

static func from_dictionary(data: Dictionary) -> _PropertyStoreSnapshot:
	var snapshot := _PropertyStoreSnapshot.new()
	snapshot._snapshot = data
	return snapshot

func set_value(property_path: String, data: Variant):
	_snapshot[property_path] = data

func get_value(property_path: String) -> Variant:
	return _snapshot[property_path]

func properties() -> Array:
	return _snapshot.keys()

func size() -> int:
	return _snapshot.size()

func equals(other: _PropertyStoreSnapshot):
	return _snapshot == other._snapshot

func is_empty() -> bool:
	return _snapshot.is_empty()

static func extract(properties: Array[PropertyEntry]) -> _PropertyStoreSnapshot:
	var result = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	return _PropertyStoreSnapshot.from_dictionary(result)

func apply(cache: PropertyCache):
	for property_path in _snapshot:
		var property_entry = cache.get_entry(property_path)
		var value = _snapshot[property_path]
		property_entry.set_value(value)

func merge(data: _PropertyStoreSnapshot) -> _PropertyStoreSnapshot:
	var result = _snapshot.duplicate()
	for key in data.as_dictionary():
		result[key] = data._snapshot[key]
	#_snapshot = result
	return _PropertyStoreSnapshot.from_dictionary(result)

func make_patch(data: _PropertyStoreSnapshot) -> _PropertyStoreSnapshot:
	var result: Dictionary = {}

	for property_path in data.properties():
		var old_property = get_value(property_path)
		var new_property = data.get_value(property_path)

		if old_property != new_property:
			result[property_path] = new_property

	return _PropertyStoreSnapshot.from_dictionary(result)

func sanitize(sender: int, property_cache: PropertyCache) -> bool:
	var sanitized := {}

	for property in _snapshot.keys():
		var property_entry := property_cache.get_entry(property)
		var authority = property_entry.node.get_multiplayer_authority()

		if authority == sender:
			sanitized[property] = _snapshot[property]
		else:
			_logger.warning(
				"Received data for property %s, owned by %s, from sender %s",
				[ property, authority, sender ]
			)

	if sanitized.is_empty():
		return false

	_snapshot = sanitized
	return true
