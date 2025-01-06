extends SceneTree
class_name VestCLI

func _init() -> void:
	# Load manually to ensure script is present
	print("Huh?")
	var runner_script = preload("res://addons/vest/vest-runner.gd")
	print("Loaded script:", runner_script)

	# Create runner
	var runner = runner_script.new()
	root.add_child(runner)

	# Run tests
	var results := runner.run_tests()
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(runner.as_tap(results))

	quit()
