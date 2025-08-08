extends "res://addons/vest/runner/vest-base-runner.gd"
class_name VestLocalRunner

## Run a test script
func run_script(script: Script) -> VestResult.Suite:
	if not script:
		return null

	var test_instance = script.new()

	var results: VestResult.Suite = null
	if test_instance is VestTest:
		await test_instance._begin(test_instance)
		var suite = await test_instance._get_suite()
		results = await _run_suite(suite, test_instance)
		await test_instance._finish(test_instance)
	test_instance.free()

	return results

## Run test scripts matching glob
## [br][br]
## See [method String.match]
func run_glob(glob: String) -> VestResult.Suite:
	var result := VestResult.Suite.new()
	result.suite = VestDefs.Suite.new()
	result.suite.name = "Glob suite \"%s\"" % [glob]

	for test_file in Vest.glob(glob):
		var suite_result := await run_script_at(test_file)
		if suite_result:
			result.subsuites.append(suite_result)

	return result

func _run_case(case: VestDefs.Case, test_instance: VestTest) -> VestResult.Case:
	await test_instance._begin(case)
	await case.callback.call()
	await test_instance._finish(case)

	return test_instance._get_result()

func _run_suite(suite: VestDefs.Suite, test_instance: VestTest) -> VestResult.Suite:
	var result := VestResult.Suite.new()
	result.suite = suite

	await test_instance._begin(suite)

	for subsuite in suite.suites:
		var suite_result := await _run_suite(subsuite, test_instance)
		result.subsuites.append(suite_result)

	for case in suite.cases:
		var case_result := await _run_case(case, test_instance)
		result.cases.append(case_result)

	await test_instance._finish(suite)

	return result
