extends VestTest

func get_suite_name() -> String:
	return "RollbackSynchronizer"

func suite():
	define("Input age and predicting", func():
		test("should return -1 on no input", func(): todo())
		test("should return 0 on recent input", func(): todo())
		test("should return positive on old input", func(): todo())
	)
