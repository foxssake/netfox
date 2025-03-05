class_name VestResult

## Grouping class for test result primitives.
##
## See [VestResult.Suite][br]
## See [VestResult.Case][br]

enum {			## Result status enum
	TEST_VOID,	## Test ran no assertions
	TEST_TODO,	## Test is not implemented yet
	TEST_FAIL,	## Test has failed
	TEST_SKIP,	## Test was skipped
	TEST_PASS	## Test passed
}

## Test suite results.
class Suite:
	## The test suite this result describes
	var suite: VestDefs.Suite

	## The results of the test cases belonging to the suite
	var cases: Array[Case] = []

	## The results of the suite's nested suites
	var subsuites: Array[Suite] = []

	## Get the number of test cases in the suite.[br]
	## Includes the number of test cases in the suite, and recursively sums up
	## the test cases in any of the nested suites.
	func size() -> int:
		return cases.size() + subsuites.reduce(func(acc, it): return acc + it.size(), 0)

	## Get the aggregate result of the test cases and suites contained in the
	## suite.
	func get_aggregate_status() -> int:
		var result: int = TEST_PASS
		if not cases.is_empty():
			result = mini(result, cases.map(func(it): return it.status).min())
		if not subsuites.is_empty():
			result = mini(result, subsuites.map(func(it): return it.get_aggregate_status()).min())
		return result

	## Get the aggregate result of the test suite, as a string.
	func get_aggregate_status_string() -> String:
		return VestResult.get_status_string(get_aggregate_status())

	## Get the count of test cases and nested suites with the given result
	## status.
	## [br][br]
	## [b]Note:[/b] This method doesn't do recursive summation.
	func get_count_by_status(p_status: int) -> int:
		return (
			cases.filter(func(it): return it.status == p_status).size() +
			subsuites.filter(func(it): return it.get_aggregate_status() == p_status).size()
		)

	func _to_wire() -> Dictionary:
		return {
			"suite": suite._to_wire(),
			"cases": cases.map(func(it): return it._to_wire()),
			"subsuites": subsuites.map(func(it): return it._to_wire())
		}

	static func _from_wire(data: Dictionary) -> Suite:
		var result := Suite.new()

		result.suite = VestDefs.Suite._from_wire(data["suite"])
		result.cases.assign(data["cases"].map(func(it): return Case._from_wire(it)))
		result.subsuites.assign(data["subsuites"].map(func(it): return Suite._from_wire(it)))

		return result

## Test case result.
class Case:
	## The test case this result describes.
	var case: VestDefs.Case

	## The resulting status of the test run.
	var status: int = TEST_VOID

	## The message attached to this result.
	var message: String = ""

	## Custom data attached to this result.
	var data: Dictionary = {}

	## The resource path where the last assertion ran.
	var assert_file: String = ""

	## The line index where the last assertion ran.[br]
	## Set to -1 for undetermined.
	var assert_line: int = -1

	## Get the test result status as a string.
	func get_status_string() -> String:
		return VestResult.get_status_string(status)

	func _to_wire() -> Dictionary:
		return {
			"case": case._to_wire(),
			"status": status,
			"message": message,
			"data": data,
			"assert_file": assert_file,
			"assert_line": assert_line
		}

	static func _from_wire(p_data: Dictionary) -> Case:
		var result := Case.new()

		result.case = VestDefs.Case._from_wire(p_data["case"])
		result.status = p_data["status"]
		result.message = p_data["message"]
		result.data = p_data["data"]
		result.assert_file = p_data["assert_file"]
		result.assert_line = p_data["assert_line"]

		return result

## Convert a test result status into string.
static func get_status_string(p_status: int) -> String:
	match p_status:
		TEST_VOID: return "VOID"
		TEST_TODO: return "TODO"
		TEST_FAIL: return "FAIL"
		TEST_SKIP: return "SKIP"
		TEST_PASS: return "PASS"
		_: return "?"
