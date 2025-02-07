extends VestTest

func get_suite_name() -> String:
	return "PropertyStoreSnapshot"

func test_diff_should_be_empty():
	# Given
	var from := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})
	
	var to := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})
	
	var expected := PropertyStoreSnapshot.deserialize({})
	
	# When
	var actual := to.get_diffs_from(from)
	
	# Then
	expect_equal(actual.serialize(), expected.serialize())

func test_diff_should_add_unknown():
	# Given
	var from := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 }
	})
	
	var to := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})
	
	var expected := PropertyStoreSnapshot.deserialize({
		"bar": { 0: "bar", 1: 18 }
	})
	
	# When
	var actual := to.get_diffs_from(from)
	
	# Then
	expect_equal(actual.serialize(), expected.serialize())

func test_diff_should_add_differing():
	# Given
	var from := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})
	
	var to := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 35 },
		"bar": { 0: "bar", 1: 18 },
	})
	
	var expected := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 35 },
	})
	
	# When
	var actual := to.get_diffs_from(from)
	
	# Then
	expect_equal(actual.serialize(), expected.serialize())

func test_diff_should_exclude_removed():
	# Given
	var from := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 },
		"bar": { 0: "bar", 1: 18 },
	})
	
	var to := PropertyStoreSnapshot.deserialize({
		"foo": { 0: "foo", 1: 15 },
	})
	
	var expected := PropertyStoreSnapshot.deserialize({})
	
	# When
	var actual := to.get_diffs_from(from)
	
	# Then
	expect_equal(actual.serialize(), expected.serialize())
