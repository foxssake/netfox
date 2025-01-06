@tool
extends SceneTree
class_name VestCLI

func _init() -> void:
	# Wait for main loop?
	for i in range(8192):
		await create_timer(0.1).timeout
		if Engine.get_main_loop() != null:
			print("Main loop present after %d iterations" % [i])
			break
	
	var runner := VestRunner.new()
	root.add_child(runner)
	
	var results := runner.run_tests()
	var tap_string := runner.as_tap(results)
	
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(tap_string)
	
	print("Saved results to vest.log")
	print(tap_string)

	quit(0 if runner.is_success(results) else 1)
