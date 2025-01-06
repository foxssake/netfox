extends SceneTree
class_name VestCLI

func _init() -> void:
	# Preload scene
	var cli_scene := preload("res://addons/vest/cli/vest-cli.tscn") as PackedScene
	var cli = cli_scene.instantiate()
	root.add_child(cli)
