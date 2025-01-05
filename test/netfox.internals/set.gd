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

func get_suite_name() -> String:
	return "Set"

#region add()
func test_add_should_persist() -> void:
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

#endregion

#region has()
func test_should_have_known_items() -> void:
	# Given
	var set := _Set.new()
	set.add(2)
	
	# When + Then
	expect(set.has(2))

func test_should_not_have_unknown_items() -> void:
	# Given
	var set := _Set.new()
	set.add(2)
	
	# When + Then
	expect_not(set.has("Foo"))

#endregion

#region size() + is_empty()
func test_new_set_should_be_empty() -> void:
	# Given
	var set := _Set.new()
	
	# Then
	expect(set.is_empty())
	expect_equal(set.size(), 0)

func test_set_should_not_be_empty() -> void:
	# Given
	var set := _Set.new()
	
	# When
	set.add("foo")
	set.add("bar")
	
	# Then
	expect_not(set.is_empty())
	expect_equal(set.size(), 2)
#endregion

func test_fail() -> void:
	fail("This suite shall fall!")
