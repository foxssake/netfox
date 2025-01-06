extends SceneTree
class_name VestCLI

func _init() -> void:
	# Ensure scripts are loaded
	preload("res://addons/vest/vest-runner.gd")

	# Create runner
	var runner := VestRunner.new()
	root.add_child(runner)

	# Run tests
	var results := runner.run_tests()
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(runner.as_tap(results))

	quit()
