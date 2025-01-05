extends VestTest

func get_suite_name() -> String:
	return "Set"

#region add() + values()
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

#region erase() + clear()
func test_erase_should_remove() -> void:
	# Given
	var set := _Set.new()
	set.add("foo")
	set.add("bar")
	set.add("quix")
	var expected = ["foo", "quix"]

	# When
	set.erase("bar")

	# Then
	expect_equal(set.values(), expected)

func test_clear_should_make_empty() -> void:
	# Given
	var set := _Set.new()
	set.add("foo")
	set.add("bar")
	set.add("quix")

	# When
	set.clear()

	# Then
	expect(set.is_empty())
#endregion
