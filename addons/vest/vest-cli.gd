extends SceneTree
class_name VestCLI

func _init() -> void:
	var runner := VestRunner.new()
	root.add_child(runner)

	var results := runner.run_tests()
	var file := FileAccess.open("res://tap.log", FileAccess.WRITE)
	file.store_string(runner.as_tap(results))

	quit()
