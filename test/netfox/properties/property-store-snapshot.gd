extends VestTest

func get_suite_name() -> String:
	return "PropertyStoreSnapshot"

func test_diff_should_be_empty():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
		"bar": 18,
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
		"bar": 18,
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({})

	# When
	var actual := from.make_patch(to)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())

func test_diff_should_add_unknown():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
		"bar": 18,
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({
		"bar": 18,
	})

	# When
	var actual := from.make_patch(to)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())

func test_diff_should_add_differing():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
		"bar": 18,
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": 35,
		"bar": 18,
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({
		"foo": 35
	})

	# When
	var actual := from.make_patch(to)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())

func test_diff_should_exclude_removed():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
		"bar": 18,
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": 15,
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({})

	# When
	var actual := from.make_patch(to)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())
