extends Node
class_name VestTest

class Case:
	var module: String
	var name: String
	var callback: Callable

	func _init(p_module: String, p_name: String, p_callback: Callable):
		module = p_module
		name = p_name
		callback = p_callback

	func get_display_name() -> String:
		return "%s - %s" % [module, name]

	func _to_string() -> String:
		return "VestTest.Case[module=%s, name=%s, callback=%s]" % [module, name, callback]

class Result:
	var case: Case
	var status: int
	var messages: PackedStringArray
	
	func is_success() -> bool:
		return status == PASS
	
	func get_status_string() -> String:
		return VestTest.status_string(status)

	func get_status_emoji() -> String:
		return VestTest.status_emoji(status)

	func _to_string() -> String:
		return "VestTest.Result[status=%s, case=%s, messages=%s]" % [VestTest.status_string(status), case, messages]

enum {
	UNKNOWN = 0,
	FAIL = 1,
	SKIP = 2,
	PASS = 3
}

var _result := Result.new()

static func status_string(status: int) -> String:
	match status:
		UNKNOWN: return "UNKNOWN"
		FAIL: return "FAIL"
		SKIP: return "SKIP"
		PASS: return "PASS"
		_: return "?%d" % [status]

static func status_emoji(status: int) -> String:
	match status:
		VestTest.UNKNOWN: return "❓"
		VestTest.FAIL: return "❌"
		VestTest.SKIP: return "💤"
		VestTest.PASS: return "✅"
		_: return "⭕"

func get_suite_name() -> String:
	return (get_script() as Script).resource_path

func fail(p_message: String = "") -> void:
	_result.status = FAIL
	if p_message: _result.messages.push_back(p_message)

func skip(p_message: String = "") -> void:
	_result.status = SKIP
	if p_message: _result.messages.push_back(p_message)

func ok(p_message: String = "") -> void:
	if _result.status == UNKNOWN:
		_result.status = PASS
		if p_message: _result.messages.push_back(p_message)

func expect(condition: bool, p_message: String = "") -> void:
	if condition:
		ok()
	else:
		fail(p_message)

func expect_not(condition: bool, p_message: String = "") -> void:
	if not condition:
		ok()
	else:
		fail(p_message)

func expect_equal(actual: Variant, expected: Variant) -> void:
	if actual != expected:
		fail("Actual value differs from expected! %s != %s" % [actual, expected])
	else:
		ok()

func expect_true(condition: bool, p_message: String = "") -> void:
	expect(condition, p_message)

func expect_false(condition: bool, p_message: String = "") -> void:
	expect_not(condition, p_message)

func expect_empty(object: Object, p_message: String = "Object was not empty!") -> void:
	if object.has_method("is_empty"):
		expect(object.is_empty(), p_message)
	else:
		fail("Object has no is_empty() method!")

func _get_result() -> Result:
	return _result

func _reset_result() -> void:
	_result = Result.new()
	_result.status = UNKNOWN
	_result.messages.clear()

func _get_test_cases() -> Array[Case]:
	var module := get_suite_name()
	var result: Array[Case] = []
	result.assign(get_method_list()\
		.filter(func(method): return method["name"].begins_with("test"))\
		.filter(func(method): return method["args"].is_empty())\
		.map(func(method): return method["name"])\
		.map(func(method_name):
			return Case.new(module, _format_test_name(method_name), get(method_name))))

	return result

func _format_test_name(method_name: String) -> String:
	return method_name.trim_prefix("test").capitalize()