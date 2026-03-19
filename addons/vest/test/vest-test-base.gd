extends Object

var _define_stack: Array[VestDefs.Suite] = []
var _result: VestResult.Case

var _expected_count := 0
var _actual_count := 0

signal on_begin()
signal on_suite_begin(suite: VestDefs.Suite)
signal on_case_begin(case: VestDefs.Case)
signal on_case_finish(case: VestDefs.Case)
signal on_suite_finish(case: VestDefs.Case)
signal on_finish()

func define(name: String, callback: Callable, is_only: bool = false) -> VestDefs.Suite:
	var suite = VestDefs.Suite.new()
	suite.name = name
	suite.is_only = is_only
	_define_stack.push_back(suite)

	var userland_loc := _find_userland_stack_location()
	suite.definition_file = userland_loc[0]
	suite.definition_line = userland_loc[1]

	await callback.call()

	_define_stack.pop_back()
	if not _define_stack.is_empty():
		_define_stack.back().suites.push_back(suite)

	return suite

func define_only(name: String, callback: Callable) -> VestDefs.Suite:
	return await define(name, callback, true)

func test(description: String, callback: Callable, is_only: bool = false, method_name: String = "") -> void:
	var case_def := VestDefs.Case.new()
	case_def.description = description
	case_def.is_only = is_only
	case_def.callback = callback
	case_def.method_name = method_name

	var userland_loc := _find_userland_stack_location()
	case_def.definition_file = userland_loc[0]
	case_def.definition_line = userland_loc[1]

	_define_stack.back().cases.push_back(case_def)

func test_only(description: String, callback: Callable, method_name: String = "") -> void:
	await test(description, callback, true, method_name)

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
	if message:
		_result.messages.append(message)

	# Smartly gather "got" and "expected" data
	# - If there's just one assert that sends these, have the values as-is
	# - If multiple asserts send them, gather them into arrays for the user to check
	if data.has("got"):
		if _actual_count == 0:
			_result.data["got"] = data["got"]
		elif _actual_count == 1:
			_result.data["got"] = [_result.data["got"], data["got"]]
		elif _actual_count > 1:
			_result.data["got"].append(data["got"])
		data.erase("got")
		_actual_count += 1

	if data.has("expect"):
		if _expected_count == 0:
			_result.data["expect"] = data["expect"]
		elif _expected_count == 1:
			_result.data["expect"] = [_result.data["expect"], data["expect"]]
		elif _expected_count > 1:
			_result.data["expect"].append(data["expect"])
		data.erase("expect")
		_expected_count += 1

	_result.data.merge(data, true)

	if _result.status != VestResult.TEST_VOID and status == VestResult.TEST_PASS:
		# Test already failed, don't override with PASS
		return

	_result.status = status

	var userland_loc := _find_userland_stack_location()
	_result.assert_file = userland_loc[0]
	_result.assert_line = userland_loc[1]

func _begin(what: Object):
	if what == self:
		await _emit_async(on_begin)
		await before_all()
	elif what is VestDefs.Suite:
		await _emit_async(on_suite_begin, [what])
		await before_suite(what)
	elif what is VestDefs.Case:
		_prepare_for_case(what)

		await _emit_async(on_case_begin, [what])
		await before_case(what)
	else:
		assert(false, "Beginning unknown object: %s" % [what])

func _finish(what: Object):
	if what == self:
		await _emit_async(on_finish)
		await after_all()
	elif what is VestDefs.Suite:
		await _emit_async(on_suite_finish, [what])
		await after_suite(what)
	elif what is VestDefs.Case:
		_actual_count = 0
		_expected_count = 0

		await _emit_async(on_case_finish, [what])
		await after_case(what)
	else:
		assert(false, "Finishing unknown object: %s" % [what])

func _prepare_for_case(case_def: VestDefs.Case):
	_result = VestResult.Case.new()
	_result.case = case_def

func _get_result() -> VestResult.Case:
	return _result

func _get_suite() -> VestDefs.Suite:
	return await define("OVERRIDE ME", func(): pass)

func _find_userland_stack_location() -> Array:
	var stack := get_stack()
	if stack.is_empty():
		return [(get_script() as Script).resource_path, -1]

	var trimmed_stack := stack.filter(func(it): return not it["source"].begins_with("res://addons/vest"))
	if trimmed_stack.is_empty():
		return ["<unknown>", -1]
	else:
		return [trimmed_stack[0]["source"], trimmed_stack[0]["line"]]

func _emit_async(p_signal: Signal, p_args: Array = []) -> void:
	for connection in p_signal.get_connections():
		var callable := connection["callable"] as Callable
		var flags := connection["flags"] as ConnectFlags

		if flags & CONNECT_DEFERRED:
			# TODO: Document call order and that deferred handlers are not awaited
			(func(): callable.callv(p_args)).call_deferred()
		else:
			await callable.callv(p_args)
