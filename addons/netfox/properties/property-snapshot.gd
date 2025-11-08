extends RefCounted
class_name _PropertySnapshot

# Maps property paths to their values
# Dictionary[String, Variant]
var _snapshot: Dictionary = {}

static var _logger := NetfoxLogger._for_netfox("PropertySnapshot")

func as_dictionary() -> Dictionary:
	return _snapshot.duplicate()

static func from_dictionary(data: Dictionary) -> _PropertySnapshot:
	return _PropertySnapshot.new(data)

func set_value(property_path: String, data: Variant) -> void:
	_snapshot[property_path] = data

func get_value(property_path: String) -> Variant:
	return _snapshot.get(property_path)

func properties() -> Array:
	return _snapshot.keys()

func has(property_path: String) -> bool:
	return _snapshot.has(property_path)

func size() -> int:
	return _snapshot.size()

func equals(other: _PropertySnapshot):
	return _snapshot == other._snapshot

func is_empty() -> bool:
	return _snapshot.is_empty()

func apply(cache: PropertyCache) -> void:
	for property_path in _snapshot:
		var property_entry := cache.get_entry(property_path)
		var value = _snapshot[property_path]
		property_entry.set_value(value)

func merge(data: _PropertySnapshot) -> _PropertySnapshot:
	var result := _snapshot.duplicate()
	for key in data.as_dictionary():
		result[key] = data._snapshot[key]

	return _PropertySnapshot.from_dictionary(result)

func make_patch(data: _PropertySnapshot) -> _PropertySnapshot:
	var result := {}

	for property_path in data.properties():
		var old_property = get_value(property_path)
		var new_property = data.get_value(property_path)

		if old_property != new_property:
			result[property_path] = new_property

	return _PropertySnapshot.from_dictionary(result)

func sanitize(sender: int, property_cache: PropertyCache) -> void:
	var sanitized := {}

	for property in _snapshot.keys():
		var property_entry := property_cache.get_entry(property)
		var authority := property_entry.node.get_multiplayer_authority()

		if authority == sender:
			sanitized[property] = _snapshot[property]
		else:
			_logger.warning(
				"Received data for property %s, owned by %s, from sender %s",
				[ property, authority, sender ]
			)

	_snapshot = sanitized

static func extract(properties: Array[PropertyEntry]) -> _PropertySnapshot:
	var result = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	return _PropertySnapshot.from_dictionary(result)

func _init(p_snapshot: Dictionary = {}) -> void:
	_snapshot = p_snapshot
