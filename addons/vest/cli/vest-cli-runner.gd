extends Node

@onready var runner := %"Vest Runner" as VestRunner

func _ready():
	# Run tests
	var results := runner.run_tests()
	var tap_string := runner.as_tap(results)
	
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(tap_string)
	
	print("Saved results to vest.log")
	print(tap_string)

	get_tree().quit(0 if runner.is_success(results) else 1)
