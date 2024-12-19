@tool
extends Node

var movement := Vector2.ZERO
var is_jumping := false

func _get_rollback_input_properties() -> Array:
	return ["movement", "is_jumping"]

func _get_rollback_state_properties() -> Array:
	return [
		["../MeshInstance3D", "transform"]
	]
