extends Object
class_name PropertySnapshot

static func extract(properties: Array[PropertyEntry]) -> Dictionary:
	var result = {}
	for property_entry in properties:
		result[property_entry.to_string()] = property_entry.get_value()
	result.make_read_only()
	return result

## properties is of the format <String, Variant>
static func apply(properties: Dictionary, cache: PropertyCache):
	for property_path in properties:
		var property_entry = cache.get_entry(property_path)
		var value = properties[property_path]
		property_entry.set_value(value)

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result = {}
	for key in a:
		result[key] = a[key]
	for key in b:
		result[key] = b[key]
	return result

## Dictionaries are of the format <String, Variant>
## If both dictionaries have a different value for a path, the value of the 2nd dictionary is placed in the diff.
static func diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var diff_result: Dictionary = {}
	for property_path in b:
		if (a.has(property_path) == false):
			diff_result[property_path] = b[property_path]
		elif (a[property_path] != b[property_path]):
			diff_result[property_path] = b[property_path]
	for property_path in a:
		if (b.has(property_path) == false):
			diff_result[property_path] = a[property_path]
	
	return diff_result	
