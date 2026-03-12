extends VestTest

func get_suite_name() -> String:
	return "RollbackSynchronizer"

func suite():
	# Messy to set up, keeping cases for later
	define("Input age and predicting", func():
		test("should return -1 on no input", func(): todo())
		test("should return 0 on recent input", func(): todo())
		test("should return positive on old input", func(): todo())
	)

	define("get_last_known_input()", func():
		test("should return -1 for no input", func(): todo())
		test("should return latest", func(): todo())
	)

	define("get_last_known_state()", func():
		test("should return -1 for no state", func(): todo())
		test("should return latest", func(): todo())
	)
