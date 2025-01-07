@tool
extends SceneTree
class_name VestCLI

func _init() -> void:
	var runner := VestRunner.new()
	root.add_child(runner)
	
	var results := runner.run_tests()
	var exit_code := 0 if runner.is_success(results) else 1
	var tap_string := runner.as_tap(results)
	
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(tap_string)
	file.close()

	print("Saved results to vest.log")
	print(tap_string)

	root.remove_child(runner)
	runner.free()
	results.clear()

	quit(exit_code)
