@tool
extends Node
class_name VestRunner

func _notification(what):
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		run_tests()

func run_tests(directory: String = "res://test/"):
	# Find test scripts
	var test_scripts := []

	var visited := []
	var to_visit := [directory]
	var files := []
	var da := DirAccess.open(directory)

	while not to_visit.is_empty() and visited.size() < 128:
		var at = to_visit.pop_front()
		da.change_dir(at)
		print("Visiting directory: %s" % [at])

		to_visit += Array(da.get_directories())\
			.map(func(dir): return at + "/" + dir)\
			.filter(func(dir): return not visited.has(dir))

		files += Array(da.get_files())\
			.map(func(f): return at + "/" + f)

	test_scripts = files\
		.filter(func(f: String): return f.ends_with(".gd"))\
		.map(func(f): return load(f))\
		.filter(func(s: Script): return s.get_base_script() == VestTest)\
		.map(func(s: Script): return s.new())

	print("Found tests: %s" %  [test_scripts])

	# Gather test cases
	var test_cases: Array[VestTest.Case] = test_scripts\
		.map(func(t: VestTest): return t._get_test_cases())\
		.reduce(func(a, b): return a + b)

	print("Found test cases: %s" % [test_cases])

	# Run tests
	var test_results: Array[VestTest.Result] = []
	for test_case in test_cases:
		var test_object := test_case.callback.get_object() as VestTest
		test_object._reset_result()

		test_case.callback.call()
		test_results.push_back(test_object._get_result())

	print("Test results: %s" % [test_results])
