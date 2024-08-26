extends Object
class_name PropertySnapshot

static func extract(properties: Array[PropertyEntry]) -> Dictionary:
	var result: Dictionary = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	result.make_read_only()
	return result

## Extract but in serialized format!
static func extract_serialized(properties: Array[PropertyEntry], tick_timestamp: int) -> PackedByteArray:
	var value_bytes: PackedByteArray
	value_bytes.resize(0)
	var picked_value: Variant
	var picked_serialized_value: PackedByteArray
	for picked_property in properties:
		picked_value = picked_property.get_value()
		picked_serialized_value = ValueToBytes.serialize(picked_value)
		value_bytes.append_array(picked_serialized_value)
		
	var result: PackedByteArray
	result.resize(5)
	result.encode_u32(0, tick_timestamp)
	result.encode_u8(4, value_bytes.size())
	result.append_array(value_bytes)#now that the header is added, add the values
	
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
