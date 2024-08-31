extends Object
class_name PropertiesSerializer

static func deserialize_input_properties(serialized_properties: PackedByteArray, property_entries: Array[PropertyEntry]) -> Dictionary:
	var reconstructed_dictionary: Dictionary = {} #Exclusively for that tick
	
	var property_type: Variant.Type
	var property_type_byte_size: int
	var serialized_property: PackedByteArray
	var input_byte_index: int = 0
	for picked_property_entry in property_entries:
		property_type = picked_property_entry.type
		property_type_byte_size = ValueToBytes.get_byte_size(property_type)
		serialized_property = serialized_properties.slice(input_byte_index, input_byte_index + property_type_byte_size)
		
		var picked_value = ValueToBytes.deserialize(serialized_property, property_type)
		input_byte_index += property_type_byte_size
		
		#print("path is %s and value is %s" % [picked_property_entry._path, picked_value])
		reconstructed_dictionary[picked_property_entry.to_string()] = picked_value
	return reconstructed_dictionary

## PropertySnapshot.extract() but in serialized format!
static func serialize_input_properties(property_entries: Array[PropertyEntry]) -> PackedByteArray:
	var result: PackedByteArray
	result.resize(1)
	
	var value_bytes: PackedByteArray
	value_bytes.resize(0)
	var picked_value: Variant
	var picked_serialized_value: PackedByteArray
	for picked_property_entry in property_entries:
		picked_value = picked_property_entry.get_value()
		picked_serialized_value = ValueToBytes.serialize_type(picked_value, picked_property_entry.type)
		value_bytes.append_array(picked_serialized_value)
	
	result.encode_u8(0, value_bytes.size())
	result.append_array(value_bytes)#now that the header is added, add the values

	return result

## PropertySnapshot.extract() but in serialized format!
static func serialize_state_properties(tick: int, properties: Dictionary, properties_to_include: Array[String], property_entries: Array[PropertyEntry]) -> PackedByteArray:
	var value_bytes: PackedByteArray
	value_bytes.resize(0)
	
	var picked_value: Variant
	var picked_serialized_value: PackedByteArray
	for picked_property_path in properties:
		picked_serialized_value = ValueToBytes.serialize(properties[picked_property_path])
		value_bytes.append_array(picked_serialized_value)
		
	var property_index: int = 1
	var header_property_indexes_contained: int = 0
	for picked_property_entry in property_entries:
		#If included, put it into the 2-byte bitfield
		if (properties_to_include.has(picked_property_entry.to_string())):
			header_property_indexes_contained += property_index
		property_index = property_index * 2
		
	var result: PackedByteArray
	result.resize(10)
	result.encode_u32(0, tick)
	result.encode_u16(4, value_bytes.size())
	result.encode_u32(6, header_property_indexes_contained)
	result.append_array(value_bytes)#now that the header is added, add the values
	
	return result

static func deserialize_state_properties(serialized_properties: PackedByteArray, auth_properties_template: Array[PropertyEntry], header_property_indexes_contained: int) -> Dictionary:
	var reconstructed_dictionary: Dictionary = {} #Exclusively for that tick
	
	var property_type: Variant.Type
	var property_type_byte_size: int
	var serialized_property: PackedByteArray
	var input_byte_index: int = 0
	var property_index: int = 1
	for picked_property_entry in auth_properties_template:
		if (property_index & header_property_indexes_contained == 0):
			property_index = property_index * 2
			continue
		
		property_type = picked_property_entry.type
		property_type_byte_size = ValueToBytes.get_byte_size(property_type)
		serialized_property = serialized_properties.slice(input_byte_index, input_byte_index + property_type_byte_size)
		
		var picked_value = ValueToBytes.deserialize(serialized_property, property_type)
		input_byte_index += property_type_byte_size
		property_index = property_index * 2
		
		reconstructed_dictionary[picked_property_entry.to_string()] = picked_value
	return reconstructed_dictionary
