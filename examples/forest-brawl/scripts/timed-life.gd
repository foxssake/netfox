extends Node

@export var time: float = 8.0

func _ready():
	await get_tree().create_timer(time).timeout
	queue_free()
