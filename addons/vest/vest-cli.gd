extends SceneTree
class_name VestCLI

func _init() -> void:
	# Wait for main loop?
	for i in range(8192):
		await create_timer(0.1).timeout
		if Engine.get_main_loop() != null:
			print("Main loop present after %d iterations" % [i])
			break
	
	# Preload scene
	var cli_scene := preload("res://addons/vest/cli/vest-cli.tscn") as PackedScene
	var cli = cli_scene.instantiate()
	root.add_child(cli)
