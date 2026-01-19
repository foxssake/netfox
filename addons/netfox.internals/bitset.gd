extends RefCounted
class_name _Bitset

var _data: PackedByteArray
var _bit_count: int

static func of_bools(values: Array) -> _Bitset:
	var result := _Bitset.new(values.size())
	for i in values.size():
		if values[i]:
			result.set_bit(i)
	return result

func _init(bit_count: int):
	var bytes := bit_count / 8
	if bit_count % 8 > 0:
		bytes += 1
	
	_data = PackedByteArray()
	_data.resize(bytes)
	
	_bit_count = bit_count

func bit_count() -> int:
	return _bit_count

func is_empty() -> bool:
	return _bit_count == 0

func is_not_empty() -> bool:
	return _bit_count != 0

func get_bit(idx: int) -> bool:
	assert(idx < _bit_count, "Accessing bit %d on bitset of size %d!" % [idx, _bit_count])
	var byte_idx := idx / 8
	var bit_idx := idx % 8
	
	return (_data[byte_idx] >> bit_idx) & 0x1 != 0

func set_bit(idx: int) -> void:
	assert(idx < _bit_count, "Accessing bit %d on bitset of size %d!" % [idx, _bit_count])
	var byte_idx := idx / 8
	var bit_idx := idx % 8
	
	_data[byte_idx] |= 0x1 << bit_idx

func clear_bit(idx: int) -> void:
	assert(idx < _bit_count, "Accessing bit %d on bitset of size %d!" % [idx, _bit_count])
	var byte_idx := idx / 8
	var bit_idx := idx % 8
	
	_data[byte_idx] &= ~(0x1 << bit_idx)

func toggle_bit(idx: int) -> void:
	assert(idx < _bit_count, "Accessing bit %d on bitset of size %d!" % [idx, _bit_count])
	var byte_idx := idx / 8
	var bit_idx := idx % 8
	
	_data[byte_idx] ^= 0x1 << bit_idx

func get_set_indices() -> Array[int]:
	var result := [] as Array[int]
	for i in _data.size():
		var byte := _data[i]
		
		if byte & 0x01: result.append(i * 8 + 0)
		if byte & 0x02: result.append(i * 8 + 1)
		if byte & 0x04: result.append(i * 8 + 2)
		if byte & 0x08: result.append(i * 8 + 3)
		
		if byte & 0x10: result.append(i * 8 + 4)
		if byte & 0x20: result.append(i * 8 + 5)
		if byte & 0x40: result.append(i * 8 + 6)
		if byte & 0x80: result.append(i * 8 + 7)
	return result

func equals(other) -> bool:
	if other is _Bitset:
		return other._bit_count == _bit_count and other._data == _data
	else:
		return false

func _to_string() -> String:
	if is_empty():
		return "Bitset(n=0)"
	else:
		var body := ""
		for i in _bit_count:
			if i != 0 and i % 4 == 0:
				body += " "
			if get_bit(i): body += "1"
			else: body += "0"
		return "Bitset(n=%d, %s)" % [_bit_count, body]
