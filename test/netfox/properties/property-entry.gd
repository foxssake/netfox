extends VestTest

func get_suite_name() -> String:
	return "PropertyEntry"

func test_should_be_valid_on_known_property():
	var property_entry := PropertyEntry.new()
	property_entry.node = TestNode.new()
	property_entry.property = "known_property"

	expect(property_entry.is_valid(), "Property entry is invalid!")

func test_should_be_valid_on_null_property():
	var property_entry := PropertyEntry.new()
	property_entry.node = TestNode.new()
	property_entry.property = "null_property"

	expect(property_entry.is_valid(), "Property entry is invalid!")

func test_should_be_invalid_on_unknown_property():
	var property_entry := PropertyEntry.new()
	property_entry.node = TestNode.new()
	property_entry.property = "unknown_property"

	expect_not(property_entry.is_valid(), "Property entry is valid!")

func test_should_be_invalid_on_unknown_node():
	var property_entry := PropertyEntry.new()
	property_entry.node = null
	property_entry.property = "known_property"

	expect_not(property_entry.is_valid(), "Property entry is valid!")

func test_should_be_invalid_on_invalid_node():
	var property_entry := PropertyEntry.new()
	property_entry.node = TestNode.new()
	property_entry.property = "known_property"

	property_entry.node.free()

	expect_not(property_entry.is_valid(), "Property entry is valid!")

class TestNode extends Node:
	var known_property := ""
	var null_property = null
