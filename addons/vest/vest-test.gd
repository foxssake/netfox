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

	func _to_string() -> String:
		return "VestTest.Case[module=%s, name=%s, callback=%s]" % [module, name, callback]

class Result:
	var status: int
	var messages: PackedStringArray

	func _to_string() -> String:
		return "VestTest.Result[status=%s, messages=%s]" % [VestTest.status_string(status), messages]

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

func expect_equal(actual: Variant, expected: Variant) -> void:
	if actual != expected:
		fail("Actual value differs from expected! %s != %s" % [actual, expected])
	else:
		ok()

func _get_result() -> Result:
	return _result

func _reset_result() -> void:
	_result.status = UNKNOWN
	_result.messages.clear()

func _get_test_cases() -> Array[Case]:
	var module := (get_script() as Script).resource_path
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
