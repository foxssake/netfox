extends VestTest

#func add(value):
#	_data[value] = true
#
#func has(value) -> bool:
#	return _data.has(value)
#
#func size() -> int:
#	return _data.size()
#
#func is_empty() -> bool:
#	return _data.is_empty()
#
#func erase(value):
#	return _data.erase(value)
#
#func clear():
#	_data.clear()
#
#func values() -> Array:
#	return _data.keys()

func test_add_should_persists() -> void:
	# Given
	var set := _Set.new()
	var expected := [2, "foo"]

	# When
	set.add(2)
	set.add("foo")

	# Then
	expect_equal(set.values(), expected)
	expect_equal(set.size(), 2)
	expect(not set.is_empty())
