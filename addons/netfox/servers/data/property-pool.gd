extends RefCounted
class_name _PropertyPool

var _properties_by_subject := {} # object to property array

func add(subject: Object, property: NodePath) -> void:
	if has(subject, property):
		return

	if not _properties_by_subject.has(subject):
		_properties_by_subject[subject] = [property]
	else:
		_properties_by_subject[subject].append(property)

func has(subject: Object, property: NodePath) -> bool:
	return (_properties_by_subject.get(subject, []) as Array).has(property)

func erase(subject: Object, property: NodePath) -> void:
	if not _properties_by_subject.has(subject):
		return

	var props := _properties_by_subject[subject] as Array
	props.erase(property)

	if props.is_empty():
		_properties_by_subject.erase(subject)

func get_properties_of(subject: Object) -> Array[NodePath]:
	var properties := [] as Array[NodePath]
	properties.assign(_properties_by_subject.get(subject, []))
	return properties

func get_subjects() -> Array[Object]:
	var subjects := [] as Array[Object]
	subjects.assign(_properties_by_subject.keys())
	return subjects
