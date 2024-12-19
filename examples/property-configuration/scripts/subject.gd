@tool
extends "res://examples/property-configuration/scripts/base-subject.gd"

var health := 100
var movement := Vector2.ZERO

# These properties will be picked up by StateSynchronizer
func _get_synchronized_state_properties() -> Array:
	# Inheritance is also possible this way
	return super() + ["health"]

# These properties will be picked up by TickInterpolator
func _get_interpolated_properties() -> Array:
	return ["transform"]

# These properties will be picked up by RollbackSyncrhonizer as state
func _get_rollback_state_properties() -> Array:
	return ["transform"]
