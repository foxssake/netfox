extends VestTest

func get_suite_name() -> String:
	return "_PropertyStoreSnapshot"

func test_diff_should_be_empty():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({})

	# When
	var actual := to.make_patch(from)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())

func test_diff_should_add_unknown():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 }
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({
		"bar": { 0: "bar", 1: 18 }
	})

	# When
	var actual := to.make_patch(from)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())

func test_diff_should_add_differing():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 35 },
		"bar": { 0: "bar", 1: 18 },
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 35 },
	})

	# When
	var actual := to.make_patch(from)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())

func test_diff_should_exclude_removed():
	# Given
	var from := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})

	var to := _PropertyStoreSnapshot.from_dictionary({
		"foo": { 0: "foo", 1: 15 },
	})

	var expected := _PropertyStoreSnapshot.from_dictionary({})

	# When
	var actual := to.make_patch(from)

	# Then
	expect_equal(actual.as_dictionary(), expected.as_dictionary())
