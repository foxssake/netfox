extends RefCounted
class_name Snapshot

var tick: int
var _data := {} # object to (property to variant)
var _is_authoritative := {} # object to bool, absent means false

static func make_patch(from: Snapshot, to: Snapshot, tick: int = to.tick) -> Snapshot:
	var patch := Snapshot.new(tick)

	for subject in from._data:
		# Target has no knowledge of subject, don't patch
		if not to._data.has(subject):
			continue
		# Only patch to auth subjects
		if not to.is_auth(subject):
			continue

		for property in to._data[subject]:
			# Target snapshot has different value, patch it
			if from.get_property(subject, property) != to.get_property(subject, property):
				patch.set_property(subject, property, to.get_property(subject, property))
		patch.set_auth(subject, to.is_auth(subject))

	return patch

# Each entry should be [subject, property, value]
static func of(tick: int, entries: Array[Array], auth_subjects: Array[Object]) -> Snapshot:
	var snapshot := Snapshot.new(tick)
	for entry in entries:
		var subject := entry[0] as Object
		var property := entry[1] as NodePath
		var value := entry[2] as Variant

		snapshot.set_property(subject, property, value)

	for subject in auth_subjects:
		snapshot.set_auth(subject, true)

	return snapshot

func _init(p_tick: int):
	tick = p_tick

func duplicate() -> Snapshot:
	var result := Snapshot.new(tick)
	result._data = _data.duplicate(true)
	result._is_authoritative = _is_authoritative.duplicate()
	return result

func set_auth(subject: Object, is_auth: bool) -> void:
	_is_authoritative[subject] = is_auth

func set_property(subject: Object, property: NodePath, value: Variant) -> void:
	if not _data.has(subject):
		_data[subject] = { property: value }
	else:
		_data[subject][property] = value

func record_property(subject: Object, property: NodePath) -> void:
	var value := subject.get_indexed(property)
	set_property(subject, property, value)

func get_property(subject: Object, property: NodePath) -> Variant:
	return _data.get(subject, {}).get(property)

func has_property(subject: Object, property: NodePath) -> bool:
	if not _data.has(subject):
		return false
	if not _data[subject].has(property):
		return false
	return true

func merge(snapshot: Snapshot) -> void:
	for subject in snapshot._data:
		if not _data.has(subject):
			# We have no data of the subject, copy all
			_data[subject] = snapshot._data[subject].duplicate()
			set_auth(subject, snapshot.is_auth(subject))
			continue

		if snapshot.is_auth(subject) or not is_auth(subject):
			var own_props := _data[subject] as Dictionary
			var their_props := snapshot._data[subject] as Dictionary
			own_props.merge(their_props, true)
			set_auth(subject, snapshot.is_auth(subject))

func apply() -> void:
	for subject in _data:
		for property in _data[subject]:
			var value = _data[subject][property]
			(subject as Object).set_indexed(property, value)

func sanitize(sender: int) -> void:
	var invalid_subjects := []
	for subject in _data:
		if subject is Node:
			if subject.get_multiplayer_authority() != sender:
				invalid_subjects.append(subject)

	for subject in invalid_subjects:
		_data.erase(invalid_subjects)

func has_subject(subject: Object, require_auth: bool = false) -> bool:
	if not _data.has(subject):
		return false
	if require_auth and not _is_authoritative.get(subject, false):
		return false
	return true

func has_subjects(subjects: Array, require_auth: bool = false) -> bool:
	for subject in subjects:
		if not has_subject(subject, require_auth):
			return false
	return true

func get_properties_of_node(node: Node) -> Array[NodePath]:
	var properties := [] as Array[NodePath]
	properties.assign(_data.get(node, []))
	return properties

func is_empty() -> bool:
	return _data.is_empty()

func size() -> int:
	var result := 0
	for subject in _data:
		result += (_data[subject] as Dictionary).size()
	return result

func is_auth(subject: Object) -> bool:
	return _is_authoritative.get(subject, false)

func equals(other) -> bool:
	if other is Snapshot:
		return tick == other.tick and _data == other._data and _is_authoritative == other._is_authoritative
	else:
		return false

func _to_string() -> String:
	var result := "Snapshot(#%d" % [tick]
	for subject in _data:
		for property in _data[subject]:
			var value = _data[subject][property]
			result += ", %s:%s(%s): %s" % [subject, property, _is_authoritative.get(subject, false), value]
	result += ")"
	return result

func _to_vest():
	return {
		"tick": tick,
		"data": _data,
		"is_auth": _is_authoritative
	}
