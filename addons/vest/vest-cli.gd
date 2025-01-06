extends SceneTree
class_name VestCLI

func _init() -> void:
	# Create runner
	var runner := preload("res://addons/vest/vest-runner.gd").new()
	root.add_child(runner)

	# Run tests
	var results := runner.run_tests()
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(runner.as_tap(results))

	quit()
