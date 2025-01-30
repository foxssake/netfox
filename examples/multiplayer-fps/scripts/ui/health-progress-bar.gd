extends ProgressBar

@export var player: CharacterBody3D

func _process(delta: float):
	value = player.health
