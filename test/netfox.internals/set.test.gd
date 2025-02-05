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
	var set := _Set.of(["foo", "bar", "quix"])
	var expected = ["foo", "quix"]

	# When
	set.erase("bar")

	# Then
	expect_equal(set.values(), expected)

func test_clear_should_make_empty() -> void:
	# Given
	var set := _Set.of(["foo", "bar", "quix"])

	# When
	set.clear()

	# Then
	expect_empty(set)
#endregion

#region iteration
func test_empty_should_not_be_iterable() -> void:
	# Given
	var set := _Set.new()

	# When + then
	expect_not(set._can_iterate(), "Set shouldn't be iterable")

func test_should_be_iterable() -> void:
	# Given
	var set := _Set.of([2, "Foo"])

	# When + then
	expect(set._can_iterate(), "Set should be iterable")

func test_iterate_should_yield_values() -> void:
	# Given
	var set := _Set.of([1, 2, "Foo", {}])
	var expected := [1, 2, "Foo", {}]
	var iterated := []

	# When
	for item in set:
		iterated.append(item)

	# Then
	expect_equal(iterated, expected)
#endregion

func test_min_max() -> void:
	# Given
	var set := _Set.of([2, 1, 3])
	
	# When + Then
	expect_equal(set.min(), 1)
	expect_equal(set.max(), 3)
