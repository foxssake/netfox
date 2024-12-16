@tool
extends CharacterBody3D

var health := 100

func _get_synchronized_state_properties() -> Array:
	return ["name", "health"]
