extends Object
class_name TAPReporter

## Generates reports in the Test Anything Protocol format
##
## See [url]https://testanything.org/[/url]

const INDENT_SIZE := 2

## Generate a report from test suite results
static func report(suite: VestResult.Suite) -> String:
	var lines := PackedStringArray()

	lines.append("TAP version 14")

	_report_suite(suite, lines, 0)

	return "\n".join(lines)

static func _report_suite(suite: VestResult.Suite, lines: PackedStringArray, indent: int = 0):
	var indent_prefix := " ".repeat(indent)
	var test_count := suite.size()
	var test_id := 1

	lines.append(indent_prefix + "1..%d" % [test_count])

	for subsuite in suite.subsuites:
		lines.append(indent_prefix + "# Subtest: %s" % [subsuite.suite.name])
		_report_suite(subsuite, lines, indent + INDENT_SIZE)
		_report_subsuite_results(test_id, subsuite, lines, indent)
		test_id += 1

	for case in suite.cases:
		_report_case(test_id, case, lines, indent)
		test_id += 1

static func _report_case(test_id: int, case: VestResult.Case, lines: PackedStringArray, indent: int = 0):
	var indent_prefix := " ".repeat(indent)
	var test_point := "ok"
	if case.status == VestResult.TEST_FAIL:
		test_point = "not ok"

	var description := case.case.description

	var directive = ""
	match case.status:
		VestResult.TEST_TODO: directive = "\t# TODO"
		VestResult.TEST_SKIP: directive = "\t# SKIP"

	lines.append(indent_prefix + "%s %d - %s%s" % [test_point, test_id, description, directive])

	var yaml_data = {}

	if case.status == VestResult.TEST_FAIL:
		yaml_data["severity"] = "fail"
		yaml_data["assert_source"] = case.assert_file
		yaml_data["assert_line"] = case.assert_line
	if case.message: yaml_data["message"] = case.message
	if case.data: yaml_data["data"] = case.data

	if not yaml_data.is_empty():
		_report_yaml(yaml_data, lines, indent + INDENT_SIZE)

static func _report_subsuite_results(test_id: int, subsuite: VestResult.Suite, lines: PackedStringArray, indent: int = 0):
	var indent_prefix := " ".repeat(indent)

	var test_point = "ok"
	if subsuite.get_count_by_status(VestResult.TEST_FAIL) > 0:
		test_point = "not ok"

	lines.append(indent_prefix + "%s %d - %s" % [test_point, test_id, subsuite.suite.name])

	if test_point != "ok":
		var yaml_data = {
			"pass": subsuite.get_count_by_status(VestResult.TEST_PASS),
			"fail": subsuite.get_count_by_status(VestResult.TEST_FAIL),
			"skip": subsuite.get_count_by_status(VestResult.TEST_SKIP),
			"todo": subsuite.get_count_by_status(VestResult.TEST_TODO)
		}
		_report_yaml(yaml_data, lines, indent + INDENT_SIZE)

static func _report_yaml(data: Dictionary, lines: PackedStringArray, indent: int = 0):
	var indent_prefix := " ".repeat(indent)

	lines.append(indent_prefix + "---")
	lines.append(YAMLWriter.stringify(data, indent))
	lines.append(indent_prefix + "...")
