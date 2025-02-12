class_name _PropertyStoreSnapshot extends RefCounted

# Typed as Dictionary[String, Variant]
var _snapshot: Dictionary = {}

func as_dictionary() -> Dictionary:
	return _snapshot.duplicate()

static func from_dictionary(data: Dictionary) -> _PropertyStoreSnapshot:
	var snapshot := _PropertyStoreSnapshot.new()
	snapshot._snapshot = data
	return snapshot

func set_value(key: String, data: Variant):
	_snapshot[key] = data

func get_value(key: String) -> Variant:
	return _snapshot[key]

func size() -> int:
	return _snapshot.size()

func equals(data: _PropertyStoreSnapshot):
	return _snapshot == data._snapshot

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
	_snapshot = result
	return self

func make_patch(data: _PropertyStoreSnapshot) -> _PropertyStoreSnapshot:
	var result: Dictionary = {}
	
	for property_path in data.as_dictionary():
		var old_property = _snapshot.get(property_path)
		var new_property = data.get(property_path)
		
		if old_property != new_property:
			result[property_path] = new_property
	
	return _PropertyStoreSnapshot.from_dictionary(result)
