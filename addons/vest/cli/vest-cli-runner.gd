extends Node

@onready var runner := %"Vest Runner" as VestRunner

func _ready():
	# Run tests
	var results := runner.run_tests()
	var file := FileAccess.open("res://vest.log", FileAccess.WRITE)
	file.store_string(runner.as_tap(results))

	get_tree().quit(0 if runner.is_success(results) else 1)
