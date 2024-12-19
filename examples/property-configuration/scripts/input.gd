@tool
extends Node

var movement := Vector2.ZERO
var is_jumping := false

# These properties will be picked up by RollbackSynchronizer as input
func _get_rollback_input_properties() -> Array:
	return ["movement", "is_jumping"]

# These properties will be picked up by StateSynchronizer as state
# NOTE that node paths are considered relative to this node, not the root!
func _get_rollback_state_properties() -> Array:
	return [
		["../MeshInstance3D", "transform"]
	]
