extends Object
class_name PropertySnapshot

static func extract(properties: Array[PropertyEntry]) -> Dictionary:
	var result: Dictionary = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	result.make_read_only()
	return result

static func extract_serialized(properties: Array[PropertyEntry], tick_timestamp: int) -> PackedByteArray:
	var result: PackedByteArray
	result.resize(4)
	result.encode_u32(0, tick_timestamp)
	
	var picked_value: Variant
	for picked_property in properties:
		picked_value = picked_property.get_value()
		result.append_array(ValueToBytes.serialize(picked_value))
		print("Picked property %s of value %s and byte size: %s" % [picked_property._to_string(), picked_value, result.size()])
		
	return result

static func apply(properties: Dictionary, cache: PropertyCache):
	for property in properties:
		var pe = cache.get_entry(property)
		var value = properties[property]
		pe.set_value(value)

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result = {}
	for key in a:
		result[key] = a[key]
	for key in b:
		result[key] = b[key]
	return result
