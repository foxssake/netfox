extends Object

var _define_stack: Array[VestDefs.Suite] = []
var _result: VestResult.Case

signal on_begin()
signal on_suite_begin(suite: VestDefs.Suite)
signal on_case_begin(case: VestDefs.Case)
signal on_case_finish(case: VestDefs.Case)
signal on_suite_finish(case: VestDefs.Case)
signal on_finish()

func define(name: String, callback: Callable) -> VestDefs.Suite:
	var suite = VestDefs.Suite.new()
	suite.name = name
	_define_stack.push_back(suite)

	var userland_loc := _find_userland_stack_location()
	suite.definition_file = userland_loc[0]
	suite.definition_line = userland_loc[1]

	callback.call()

	_define_stack.pop_back()
	if not _define_stack.is_empty():
		_define_stack.back().suites.push_back(suite)

	return suite

func test(description: String, callback: Callable) -> void:
	var case_def := VestDefs.Case.new()
	case_def.description = description
	case_def.callback = callback

	var userland_loc := _find_userland_stack_location()
	case_def.definition_file = userland_loc[0]
	case_def.definition_line = userland_loc[1]

	_define_stack.back().cases.push_back(case_def)

func benchmark(name: String, callback: Callable) -> VestDefs.Benchmark:
	var result := VestDefs.Benchmark.new()
	result.name = name
	result.callback = callback
	result._test = self
	return result

func todo(message: String = "", data: Dictionary = {}) -> void:
	_with_result(VestResult.TEST_TODO, message, data)

func skip(message: String = "", data: Dictionary = {}) -> void:
	_with_result(VestResult.TEST_SKIP, message, data)

func fail(message: String = "", data: Dictionary = {}) -> void:
	_with_result(VestResult.TEST_FAIL, message, data)

func ok(message: String = "", data: Dictionary = {}) -> void:
	_with_result(VestResult.TEST_PASS, message, data)

func before_all():
	pass

func before_suite(_suite_def: VestDefs.Suite):
	pass

func before_case(_case_def: VestDefs.Case):
	pass

func after_case(_case_def: VestDefs.Case):
	pass

func after_suite(_suite_def: VestDefs.Suite):
	pass

func after_all():
	pass

func _init():
	pass

func _with_result(status: int, message: String, data: Dictionary):
	if _result.status != VestResult.TEST_VOID and status == VestResult.TEST_PASS:
		# Test already failed, don't override with PASS
		return

	_result.status = status
	_result.message = message
	_result.data.merge(data, true)

	var userland_loc := _find_userland_stack_location()
	_result.assert_file = userland_loc[0]
	_result.assert_line = userland_loc[1]

func _begin(what: Object):
	if what == self:
		on_begin.emit()
		before_all()
	elif what is VestDefs.Suite:
		on_suite_begin.emit(what)
		before_suite(what)
	elif what is VestDefs.Case:
		_prepare_for_case(what)

		on_case_begin.emit(what)
		before_case(what)
	else:
		push_error("Beginning unknown object: %s" % [what])

func _finish(what: Object):
	if what == self:
		on_finish.emit()
		after_all()
	elif what is VestDefs.Suite:
		on_suite_finish.emit(what)
		after_suite(what)
	elif what is VestDefs.Case:
		on_case_finish.emit(what)
		after_case(what)
	else:
		push_error("Finishing unknown object: %s" % [what])

func _prepare_for_case(case_def: VestDefs.Case):
	_result = VestResult.Case.new()
	_result.case = case_def

func _get_result() -> VestResult.Case:
	return _result

func _get_suite() -> VestDefs.Suite:
	return define("OVERRIDE ME", func():)

func _find_userland_stack_location() -> Array:
	var stack := get_stack()
	if stack.is_empty():
		return [(get_script() as Script).resource_path, -1]

	var trimmed_stack := stack.filter(func(it): return not it["source"].begins_with("res://addons/vest"))
	if trimmed_stack.is_empty():
		return ["<unknown>", -1]
	else:
		return [trimmed_stack[0]["source"], trimmed_stack[0]["line"]]
