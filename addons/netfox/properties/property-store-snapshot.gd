class_name _PropertyStoreSnapshot extends RefCounted

# Typed as Dictionary[String, Variant]
var _snapshot: Dictionary = {}

func as_dictionary() -> Dictionary:
	return _snapshot

static func from_dictionary(data: Dictionary) -> _PropertyStoreSnapshot:
	var snapshot := _PropertyStoreSnapshot.new()
	snapshot._snapshot = data
	return snapshot

func set_value(key: String, data: Variant):
	_snapshot[key] = data

func get_value(key: String) -> Variant:
	return _snapshot[key]

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

# TODO: Simplify
func merge(b: _PropertyStoreSnapshot) -> _PropertyStoreSnapshot:
	var result = {}
	for key in _snapshot:
		result[key] = _snapshot[key]
	for key in b.as_dictionary():
		result[key] = b._snapshot[key]
	_snapshot = result
	return self

func make_patch(b: _PropertyStoreSnapshot) -> _PropertyStoreSnapshot:
	var result: Dictionary = {}
	
	for property_path in b.as_dictionary():
		var va = _snapshot.get(property_path)
		var vb = b.get(property_path)
		
		if va != vb:
			result[property_path] = vb
	
	return _PropertyStoreSnapshot.from_dictionary(result)

func size() -> int:
	return _snapshot.size()

func equals(data: _PropertyStoreSnapshot):
	return _snapshot == data._snapshot
