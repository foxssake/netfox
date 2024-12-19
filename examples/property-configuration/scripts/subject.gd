@tool
extends "res://examples/property-configuration/scripts/base-subject.gd"

var health := 100
var movement := Vector2.ZERO

func _get_synchronized_state_properties() -> Array:
	return super() + ["health"]

func _get_interpolated_properties():
	return ["transform"]

func _get_rollback_state_properties():
	return ["transform"]
