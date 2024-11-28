extends Object
class_name PropertySnapshot

static func extract(properties: Array[PropertyEntry]) -> Dictionary:
	var result = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	result.make_read_only()
	return result

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

static func make_patch(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	
	for property_path in b:
		var va = a.get(property_path)
		var vb = b.get(property_path)
		
		if va != vb:
			result[property_path] = vb
	
	return result
