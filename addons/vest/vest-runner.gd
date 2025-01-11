@tool
extends Node
class_name VestRunner

func _notification(what):
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		print(as_tap(run_tests()))

func run_tests(directory: String = "res://test/") -> Array[VestTest.Result]:
	# Find test suites
	var test_suites: Array[VestTest] = []

	var visited := []
	var to_visit := [directory]
	var files := []
	var da := DirAccess.open(directory)

	while not to_visit.is_empty():
		var at = to_visit.pop_front()
		da.change_dir(at)

		to_visit += Array(da.get_directories())\
			.map(func(dir): return at + "/" + dir)\
			.filter(func(dir): return not visited.has(dir))

		files += Array(da.get_files())\
			.map(func(f): return at + "/" + f)

	test_suites.assign(files\
		.filter(func(f: String): return f.ends_with(".gd"))\
		.map(func(f): return load(f))\
		.filter(func(s: Script): return s.get_base_script() == VestTest)\
		.map(func(s: Script): return s.new()))

	# Iterate test suites for tests
	var test_results: Array[VestTest.Result] = []

	for test_suite in test_suites:
		var test_cases := test_suite._get_test_cases()

		# Run suite
		test_suite.before()
		for test_case in test_cases:
			test_suite.before_each()
			test_suite._reset_result()

			test_case.callback.call()
			var test_result := test_suite._get_result()
			test_result.case = test_case
			test_results.push_back(test_result)

			test_suite.after_each()

		test_suite.after()

		# Free suite
		test_suite.queue_free()

	return test_results

func as_tap(results: Array[VestTest.Result]) -> String:
	var lines := PackedStringArray()

	lines.append("TAP version 14")
	lines.append("1..%d" % [results.size()])

	for idx in range(results.size()):
		var result := results[idx]
		var case := result.case

		if result.status == VestTest.PASS:
			lines.append("ok %d - %s/%s" % [idx + 1, case.module, case.name])
		else:
			lines.append("not ok %d - %s" % [idx + 1, case.name])
			lines.append("  ---")
			lines.append("  severity: fail")
			
			if result.messages.is_empty():
				lines.append("  messages: []")
			else:
				lines.append("  messages:")
				lines.append_array(Array(result.messages)\
					.map(func(message: String): return "    - \"%s\"" % [message.c_escape()]))
			lines.append("  ...")

	lines.append("")

	return "\n".join(lines)

func is_success(results: Array[VestTest.Result]) -> bool:
	return results.all(func(result: VestTest.Result): return result.status == VestTest.PASS)

func aggregate_results(results: Array[VestTest.Result]) -> int:
	return results.map(func(it): return it.status).min()
