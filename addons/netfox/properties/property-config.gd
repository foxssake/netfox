extends RefCounted
class_name _PropertyConfig

var _properties: Array[PropertyEntry] = []
var _auth_properties: Dictionary = {} # Peer (int) to owned properties (Array[PropertyEntry])

var local_peer_id: int

func clear() -> void:
	_properties.clear()
	_auth_properties.clear()

func set_properties(p_properties: Array[PropertyEntry]) -> void:
	clear()
	_properties.assign(p_properties)

func set_properties_from_paths(property_paths: Array[String], property_cache: PropertyCache) -> void:
	clear()
	for path in property_paths:
		_properties.append(property_cache.get_entry(path))

func get_properties() -> Array[PropertyEntry]:
	return _properties

func get_owned_properties() -> Array[PropertyEntry]:
	return get_properties_owned_by(local_peer_id)

func get_properties_owned_by(peer: int) -> Array[PropertyEntry]:
	if not _auth_properties.has(peer):
		var owned_properties: Array[PropertyEntry] = []
		for property_entry in _properties:
			if property_entry.node.get_multiplayer_authority() == peer:
				owned_properties.append(property_entry)
		_auth_properties[peer] = owned_properties

	return _auth_properties[peer]
