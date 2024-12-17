@tool
extends Node

var movement := Vector2.ZERO
var is_jumping := false

func _get_rollback_input_properties():
	return ["movement", "is_jumping"]
