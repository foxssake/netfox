extends RefCounted
class_name PropertyStoreSnapshot

# Typed as Dictionary[String, Property]
var _snapshot : Dictionary = {}

func size() -> int:
	return _snapshot.size()

func get_paths() -> Array[String]:
	var array: Array[String] = []
	for key in _snapshot.keys():
		array.push_back(key as String)
	return array

func get_property(key: String) -> Property:
	return _snapshot[key]

func get_properties() -> Array[Property]:
	var array: Array[Property] = []
	for property in _snapshot.values():
		array.push_back(property as Property)
	return array

func set_property(key: String, value: Property):
	_snapshot[key] = value;

func remove_property(path: String) -> bool:
	return _snapshot.erase(path)

func get_snapshot() -> Dictionary:
	return _snapshot

func has_key(key: String) -> bool:
	return _snapshot.has(key)

func serialize() -> Dictionary:
	var serialized: Dictionary = {}
	for property in _snapshot:
		serialized[property] = _snapshot[property].serialize()
	return serialized

static func deserialize(data: Dictionary) -> PropertyStoreSnapshot:
	var deserialized := PropertyStoreSnapshot.new()
	for property in data:
		deserialized.set_property(property, Property.deserialize(data[property]))
	return deserialized

func is_empty() -> bool:
	return _snapshot.is_empty()

# b.get_diffs_from(a)
# Where b is the newer form of a, and we only want what changed in b

func get_diffs_from(reference: PropertyStoreSnapshot) -> PropertyStoreSnapshot:
	var diffs := PropertyStoreSnapshot.new()
	
	for key in _snapshot.keys():
		if not reference.has_key(key):
			diffs.set_property(key, _snapshot[key])
		elif reference.get_property(key).value != _snapshot[key].value:
			diffs.set_property(key, _snapshot[key])
	
	return diffs

func make_read_only():
	_snapshot.make_read_only()

func erase(tick: int):
	_snapshot.erase(tick)

static func create_from(properties: Array[PropertyEntry]) -> PropertyStoreSnapshot:
	var result := PropertyStoreSnapshot.new()
	
	for entry in properties:
		var property := Property.new()
		property.path = entry.to_string()
		property.value = entry.get_value()
		result.set_property(property.path, property)
	
	# TODO: Ensure commenting out this line is correct.
	#result.make_read_only()
	return result
