extends RefCounted
class_name Snapshot

var tick: int
var data: Dictionary = {} # RecordedProperty to Variant value
var _is_authoritative: Dictionary = {} # Property key to bool, not present means false

func _init(p_tick: int):
	tick = p_tick

func set_property(node: Node, property: NodePath, value: Variant, is_authoritatve: bool = false) -> void:
	data[RecordedProperty.key_of(node, property)] = value
	_is_authoritative[RecordedProperty.key_of(node, property)] = is_authoritatve

func merge(snapshot: Snapshot) -> void:
	for prop_key in snapshot.data:
		# Merge properties that we don't have, or don't have it authoritatively
		if _is_authoritative.get(prop_key, false):
			data[prop_key] = snapshot.data[prop_key]
			_is_authoritative[prop_key] = snapshot._is_authoritative[prop_key]

func has_node(node: Node) -> bool:
	for entry in data.keys():
		if (entry as RecordedProperty).node == node:
			return true
	return false

func _to_string() -> String:
	return "Snapshot(#%d, %s)" % [tick, str(data)]
