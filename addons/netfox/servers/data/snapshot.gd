extends RefCounted
class_name Snapshot

var tick: int
var data: Dictionary = {} # RecordedProperty to Variant value
var _is_authoritative: Dictionary = {} # Property key to bool, not present means false

static func make_patch(from: Snapshot, to: Snapshot, tick: int = to.tick, include_new: bool = true) -> Snapshot:
	var patch := Snapshot.new(tick)
	
	for prop_key in from.data:
		# TODO: This works if both props are auth - handle if that differs
		if to.data.has(prop_key) and from.data[prop_key] != to.data[prop_key]:
			patch.data[prop_key] = to.data[prop_key]
			patch._is_authoritative[prop_key] = to._is_authoritative[prop_key]

	if include_new:
		for prop_key in to.data:
			# TODO: This works if both props are auth - handle if that differs
			if not from.data.has(prop_key):
				patch.data[prop_key] = to.data[prop_key]
				patch._is_authoritative[prop_key] = to._is_authoritative[prop_key]
	
	return patch

func _init(p_tick: int):
	tick = p_tick

func duplicate() -> Snapshot:
	var result := Snapshot.new(tick)
	result.data = data.duplicate()
	result._is_authoritative = _is_authoritative.duplicate()
	return result

func set_property(node: Node, property: NodePath, value: Variant, is_authoritative: bool = false) -> void:
	data[RecordedProperty.key_of(node, property)] = value
	_is_authoritative[RecordedProperty.key_of(node, property)] = is_authoritative

func get_property(node: Node, property: NodePath) -> Variant:
	return data[RecordedProperty.key_of(node, property)]

func has_property(node: Node, property: NodePath) -> bool:
	return data.has(RecordedProperty.key_of(node, property))

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

func filtered_to_auth() -> Snapshot:
	var snapshot := Snapshot.new(tick)

	for property in data:
		if not _is_authoritative[property]:
			continue

		snapshot.data[property] = data[property]
		snapshot._is_authoritative[property] = _is_authoritative[property]

	return snapshot

func filtered_to_owned() -> Snapshot:
	var snapshot := Snapshot.new(tick)

	for property in data:
		if not RecordedProperty.get_node(property).is_multiplayer_authority():
			continue

		snapshot.data[property] = data[property]
		snapshot._is_authoritative[property] = _is_authoritative[property]
	
	return snapshot

func filtered(filter: Callable) -> Snapshot:
	var snapshot := Snapshot.new(tick)

	for property in data:
		var node := RecordedProperty.get_node(property)
		var prop := RecordedProperty.get_property(property)
		if not filter.call(node, prop):
			continue

		snapshot.data[property] = data[property]
		snapshot._is_authoritative[property] = _is_authoritative[property]

	return snapshot

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

func has_nodes(nodes: Array[Node], require_auth: bool = false) -> bool:
	for entry in data.keys():
		var entry_node := entry[0] as Node
		if not nodes.has(entry_node):
			continue

		var is_auth := _is_authoritative.get(entry, false) as bool
		if require_auth and not is_auth:
			continue

		return true
	return false

func get_properties_of_node(node: Node) -> Array[NodePath]:
	var properties := [] as Array[NodePath]
	for entry in data.keys():
		var entry_node := entry[0] as Node
		var entry_path := entry[1] as NodePath
		if entry_node == node:
			properties.append(entry_path)
	return properties

func nodes() -> Array[Node]:
	var nodes := [] as Array[Node]
	for entry in data.keys():
		var entry_node := entry[0] as Node
		if not nodes.has(entry_node):
			nodes.append(entry_node)
	return nodes

func is_empty() -> bool:
	return data.is_empty()

func is_auth(node: Node, property: NodePath) -> bool:
	return _is_authoritative.get(RecordedProperty.key_of(node, property), false)

func equals(other) -> bool:
	if other is Snapshot:
		return tick == other.tick and data == other.data and _is_authoritative == other._is_authoritative
	else:
		return false

func _to_string() -> String:
	var result := "Snapshot(#%d" % [tick]
	for entry in data:
		result += ", %s(%s): %s" % [entry, _is_authoritative.get(entry, false), data[entry]]
	result += ")"
	return result

func _to_vest():
	return {
		"tick": tick,
		"data": data,
		"is_auth": _is_authoritative
	}
