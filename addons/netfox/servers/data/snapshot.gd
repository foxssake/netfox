extends RefCounted
class_name Snapshot

var tick: int
var data: Dictionary = {} # RecordedProperty to Variant value
var _is_authoritative: Dictionary = {} # Property key to bool, not present means false

func _init(p_tick: int):
	tick = p_tick

func set_property(node: Node, property: NodePath, value: Variant, is_authoritative: bool = false) -> void:
	data[RecordedProperty.key_of(node, property)] = value
	_is_authoritative[RecordedProperty.key_of(node, property)] = is_authoritative

func merge_property(node: Node, property: NodePath, value: Variant, is_authoritative: bool = false) -> bool:
	var prop_key := RecordedProperty.key_of(node, property)
	if is_authoritative or not _is_authoritative.get(prop_key, false):
		data[prop_key] = value
		_is_authoritative[prop_key] = is_authoritative
		return true
	return false

func merge(snapshot: Snapshot) -> void:
	for prop_key in snapshot.data:
		# Merge properties that we don't have, or don't have it authoritatively
		if snapshot._is_authoritative.get(prop_key, false) or not _is_authoritative.get(prop_key, false):
			data[prop_key] = snapshot.data[prop_key]
			_is_authoritative[prop_key] = snapshot._is_authoritative[prop_key]

func apply() -> void:
	for prop_key in data:
		var value = data[prop_key]
		RecordedProperty.apply(prop_key, value)

func has_node(node: Node, require_auth: bool = false) -> bool:
	for entry in data.keys():
		var entry_node := entry[0] as Node
		if entry_node != node:
			continue
		
		var is_auth := _is_authoritative.get(entry, false) as bool
		if require_auth and not is_auth:
			continue

		return true
	return false

func _to_string() -> String:
	var result := "Snapshot(#%d" % [tick]
	for entry in data:
		result += ", %s(%s): %s" % [entry, _is_authoritative.get(entry, false), data[entry]]
	result += ")"
	return result
