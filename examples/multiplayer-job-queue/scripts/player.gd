extends Node3D

@onready var input := $Input as JobQueuePlayerInput

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	$Cursor.position = input.cursor_position
	%Username.text = name
