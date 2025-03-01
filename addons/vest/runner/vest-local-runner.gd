extends "res://addons/vest/runner/vest-base-runner.gd"
class_name VestLocalRunner

## Run a test script
func run_script(script: Script) -> VestResult.Suite:
	if not script:
		return null

	var test_instance = script.new()

	var results: VestResult.Suite = null
	if test_instance is VestTest:
		test_instance._begin(test_instance)
		results = _run_suite(test_instance._get_suite(), test_instance)
		test_instance._finish(test_instance)
	test_instance.free()

	return results

## Run test scripts matching glob
## [br][br]
## See [method String.match]
func run_glob(glob: String) -> VestResult.Suite:
	var result := VestResult.Suite.new()
	result.suite = VestDefs.Suite.new()
	result.suite.name = "Glob suite \"%s\"" % [glob]

	for test_file in _glob(glob):
		var suite_result := run_script_at(test_file)
		if suite_result:
			result.subsuites.append(suite_result)

	return result

func _run_case(case: VestDefs.Case, test_instance: VestTest) -> VestResult.Case:
	test_instance._begin(case)
	case.callback.call()
	test_instance._finish(case)

	return test_instance._get_result()

func _run_suite(suite: VestDefs.Suite, test_instance: VestTest) -> VestResult.Suite:
	var result := VestResult.Suite.new()
	result.suite = suite

	test_instance._begin(suite)

	for subsuite in suite.suites:
		result.subsuites.append(_run_suite(subsuite, test_instance))

	for case in suite.cases:
		result.cases.append(_run_case(case, test_instance))

	test_instance._finish(suite)

	return result
