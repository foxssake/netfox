extends Object
class_name PropertiesSerializer

static func deserialize_multiple_properties(serialized_input: PackedByteArray, auth_input_pros: Array[PropertyEntry]) -> Dictionary:
	var reconstructed_dictionary: Dictionary = {} #Exclusively for that tick
	
	print("Deserializing multiple properties of serialized input %s  and array %s" % [serialized_input, auth_input_pros])
	var property_type: Variant.Type
	var property_type_byte_size: int
	var serialized_property: PackedByteArray
	var input_byte_index: int = 0
	for picked_property_entry in auth_input_pros:
		property_type = picked_property_entry.type
		property_type_byte_size = ValueToBytes.get_byte_size(property_type)
		serialized_property = serialized_input.slice(input_byte_index, input_byte_index + property_type_byte_size)
		
		var picked_value = ValueToBytes.deserialize(serialized_property, property_type)
		input_byte_index += property_type_byte_size
		
		print("path is %s and value is %s" % [picked_property_entry._path, picked_value])
		reconstructed_dictionary[picked_property_entry._path] = picked_value
	return reconstructed_dictionary

## Extract but in serialized format!
static func serialize_multiple_properties(properties: Array[PropertyEntry], tick_timestamp: int) -> PackedByteArray:
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
